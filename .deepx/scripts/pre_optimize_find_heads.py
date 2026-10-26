#!/usr/bin/env python3
"""Find the head tensors of a YOLO / RTMDet ONNX model and print the DX-COM
`pre_optimize` config block, optionally merged into an existing config JSON.

  pre_optimize_find_heads.py MODEL.onnx                   # {"pre_optimize": [...]}
  pre_optimize_find_heads.py MODEL.onnx --config c.json   # c.json with ppu removed, pre_optimize set
  pre_optimize_find_heads.py MODEL.onnx --verify          # also run dx_com.pre_optimize + onnxruntime check

stdout is JSON only. Notes, warnings and the verify report go to stderr.
Exit codes: 0 ok | 1 verify failed | 2 unsupported model, or overrides needed
(--task / --num-classes / --kpt-shape / --pass) | 3 error (bad path, bad JSON, ...)
| 4 verify could not compare values (VERIFY UNCHECKED).
"""
import argparse
import ast
import contextlib
import json
import sys
from collections import defaultdict

import numpy as np
import onnx
from onnx import shape_inference

DFL, NO_DFL, RTM = "yolo_dfl_postprocess", "yolo_no_dfl_postprocess", "rtmdet_postprocess"
TASKS = {"detect": "base", "segment": "seg", "pose": "pose"}
HEAD_CONSUMERS = {"Concat", "Reshape", "Transpose", "Shape"}  # no activation after a head Conv
STRIDES = (8, 16, 32, 64)
MASK_CH = 32
DEFAULT_TOPK = {DFL: 300, NO_DFL: 300, RTM: 512}  # pass defaults in source/docs/02_09_Pre_Optimize_API.md
PPU_HINT = ("pre_optimize supports YOLOv8/v9/v11/v12/v13 (DFL heads), YOLO26 (no-DFL heads) and "
            "MMDetection RTMDet. Anchor-based YOLOv3/v5/v7 (3x(5+C)-channel heads) -> PPU type 0; "
            "YOLOX (objectness head) -> PPU type 1.")


class Unsupported(Exception):
    pass


def note(msg):
    print(msg, file=sys.stderr)


def dims_of(value_info):
    return [d.dim_value if d.HasField("dim_value") else None
            for d in value_info.type.tensor_type.shape.dim]


class Graph:
    def __init__(self, path):
        model = onnx.load(path)
        try:
            model = shape_inference.infer_shapes(model)
        except Exception as e:  # custom ops: fall back to the shapes stored in the file
            note(f"NOTE: shape inference failed ({e}); using stored shapes only")
        g = model.graph
        self.g = g
        self.meta = {p.key: p.value for p in model.metadata_props}
        inits = {i.name for i in g.initializer}
        inputs = [i for i in g.input if i.name not in inits]
        self.shape = {v.name: dims_of(v) for v in list(g.input) + list(g.value_info) + list(g.output)}
        self.producer = {o: n for n in g.node for o in n.output}
        self.users = defaultdict(list)
        for n in g.node:
            for i in n.input:
                self.users[i].append(n)
        self.consumers = defaultdict(list, {t: [n.op_type for n in ns] for t, ns in self.users.items()})
        self.outputs = {o.name for o in g.output}
        if len(inputs) != 1:
            raise Unsupported(f"expected 1 model input, got {[i.name for i in inputs]}")
        self.input = inputs[0]
        d = self.shape[self.input.name]
        if len(d) != 4 or not d[2] or not d[3]:
            raise Unsupported(f"input '{self.input.name}' is {d}: pre_optimize needs a static NCHW "
                              "input H/W - re-export the model with a fixed input size")
        self.in_h, self.in_w = d[2], d[3]

    def meta_literal(self, key):
        return ast.literal_eval(self.meta[key]) if key in self.meta else None

    def reaches_concat(self, t):
        """Head tensors flow through Reshape/Transpose into a Concat or a graph output;
        look-alikes (e.g. attention projections) end in Mul/MatMul/Softmax."""
        if t in self.outputs:
            return True
        users = [n for n in self.users.get(t, []) if n.op_type != "Shape"]
        return bool(users) and all(n.op_type == "Concat" or (
            n.op_type in ("Reshape", "Transpose", "Flatten") and self.reaches_concat(n.output[0]))
            for n in users)

    def op_of(self, t):
        """op_type of the node producing `t`; None for a graph input or initializer."""
        n = self.producer.get(t)
        return n.op_type if n else None

    def concat_partners(self, t, ch):
        """Same-size Concat inputs next to `t` with `ch` channels (a class head that is not a Conv,
        e.g. the YOLO-World contrastive head)."""
        hw = self.shape[t][2:]
        return [i for n in self.users.get(t, []) if n.op_type == "Concat" for i in n.input
                if i != t and (self.shape.get(i) or [])[1:] == [ch] + hw]

    def sigmoid_heads(self, s):
        """Channels of the stride-`s` Convs activated inside the head (Conv -> Sigmoid -> Concat):
        YOLOX/YOLOv6-style. Ultralytics heads concatenate raw Conv logits."""
        chs = []
        for out, d, st in self.conv_outputs():
            users = [n for n in self.users.get(out, []) if n.op_type != "Shape"]
            if st == s and len(users) == 1 and users[0].op_type == "Sigmoid" \
                    and self.reaches_concat(users[0].output[0]):
                chs.append(d[1])
        return sorted(chs)

    def conv_outputs(self):
        """(tensor, [N,C,H,W], stride) for every Conv with a static 4D output on an integer stride."""
        for n in self.g.node:
            if n.op_type != "Conv":
                continue
            out = n.output[0]
            d = self.shape.get(out)
            if not d or len(d) != 4 or not all(d[1:]):
                continue
            if self.in_h % d[2] or self.in_w % d[3] or self.in_h // d[2] != self.in_w // d[3]:
                continue
            yield out, d, self.in_h // d[2]


def build_rtmdet(gr, args):
    cls_l, reg_l = [], []
    for out, _, s in gr.conv_outputs():
        if "rtm_cls" in out:
            cls_l.append((s, out))
        elif "rtm_reg" in out:
            reg_l.append((s, out))
    if not cls_l or len(cls_l) != len(reg_l):
        raise Unsupported(f"RTMDet heads not found by name (rtm_cls={cls_l}, rtm_reg={reg_l}); "
                          "find them in Netron (see 02_09_Pre_Optimize_API.md)")
    nms = [n for n in gr.g.node if n.op_type == "NonMaxSuppression"]
    if not nms:
        raise Unsupported("RTMDet heads found but no NonMaxSuppression node: export the model with NMS")
    scores_t = gr.producer.get(nms[0].input[1])
    if scores_t is None or scores_t.op_type != "Transpose":
        raise Unsupported(f"unexpected producer of the NMS score input: {scores_t and scores_t.op_type}")
    topk = next((n for n in gr.g.node if n.op_type == "TopK"), None)
    if topk is None:
        raise Unsupported("no TopK node before NMS")
    reg_l.sort()
    cfg = {
        "cls_layers": [o for _, o in sorted(cls_l)],  # stride 8 -> 16 -> 32
        "reg_layers": [o for _, o in reg_l],
        "use_exp": "Exp" in gr.consumers[reg_l[0][1]],
        "nms_boxes_tensor": nms[0].input[0],
        "nms_scores_tensor": scores_t.input[0],
        "nms_score_tensor": topk.output[0],
    }
    if args.topk:
        cfg["topk"] = args.topk
    return RTM, cfg, f"strides {[s for s, _ in reg_l]}, use_exp={cfg['use_exp']}"


def describe(heads):
    return "; ".join(f"stride {s}: " + ", ".join(f"{ch}ch x{len(v)}" for ch, v in sorted(heads[s].items()))
                     for s in sorted(heads)) or "none"


def build_yolo(gr, args):
    heads = defaultdict(lambda: defaultdict(list))  # stride -> channels -> [tensor names]
    for out, d, s in gr.conv_outputs():
        if s in STRIDES and set(gr.consumers[out]) <= HEAD_CONSUMERS:
            heads[s][d[1]].append(out)
    meta_task = gr.meta.get("task")
    if meta_task and meta_task not in TASKS and not args.task:
        raise Unsupported(f"metadata task is '{meta_task}': pre_optimize handles detect/segment/pose only. "
                          + PPU_HINT)
    names = gr.meta_literal("names")
    C = args.num_classes or (len(names) if names else None)
    kpt = args.kpt_shape or gr.meta_literal("kpt_shape")
    task = args.task or TASKS.get(meta_task)
    found = describe(heads)

    if not heads:
        raise Unsupported("no head Conv (Conv output fed only to Concat/Reshape/Transpose) at strides "
                          f"8/16/32. {PPU_HINT}")
    g0 = heads[min(heads)]
    anchor = [ch for ch in g0 if ch % 3 == 0 and ch // 3 > 5]
    hint = f" {anchor}ch = 3x(5+C) looks like an anchor-based head. {PPU_HINT}" if anchor else ""
    if args.pass_name:
        p = args.pass_name
    elif 64 in g0 and C != 64:
        p = DFL
    elif 4 in g0 and C != 4:
        p = NO_DFL
    else:
        raise Unsupported(f"no 64ch (DFL) or 4ch (no-DFL) bbox head Conv. Head-like Convs: {found}."
                          + (hint or " " + PPU_HINT))
    bbox_ch = 64 if p == DFL else 4
    strides = sorted(s for s in heads if bbox_ch in heads[s])
    if not strides:
        raise Unsupported(f"{p} needs {bbox_ch}ch bbox head Convs; head-like Convs: {found}")
    fine = sorted({s for out, d, s in gr.conv_outputs() if s < STRIDES[0] and d[1] == bbox_ch
                   and set(gr.consumers[out]) <= HEAD_CONSUMERS})
    if fine:
        raise Unsupported(f"{bbox_ch}ch bbox head at stride {fine} (P2-style model): {p} covers strides "
                          f"{STRIDES[0]}+ only and would silently drop that scale. " + PPU_HINT)
    for s in strides:
        act = gr.sigmoid_heads(s)
        if any(gr.op_of(t) == "Sigmoid" for b in heads[s][bbox_ch] for t in gr.concat_partners(b, 1)):
            raise Unsupported(f"stride {s}: YOLOX-style head (box head concatenated with a 1-channel objectness "
                              "tensor): pre_optimize cannot decode it - use PPU type 1. " + PPU_HINT)
        if act:
            raise Unsupported(f"stride {s}: head Convs with {act} channels go through Sigmoid inside the head "
                              "(e.g. YOLOv6). pre_optimize applies Sigmoid itself to raw class logits "
                              "(Ultralytics/RTMDet heads). " + PPU_HINT)
    others = {ch for ch in heads[strides[0]] if ch != bbox_ch}
    notes = []  # printed only when the head is resolved
    proto = [o for o in gr.g.output if (lambda d: len(d) == 4 and d[1] == MASK_CH and d[2]
                                        and gr.in_h // d[2] == 4)(gr.shape.get(o.name, []))]

    if task is None:
        if proto:
            task = "seg"
        elif kpt:
            task = "pose"
        elif (C is None and len(others) == 1) or (C is not None and others == {C}):
            task = "base"
        else:
            raise Unsupported(f"cannot infer the task (no Ultralytics metadata). Head-like Convs: {found}. "
                              "For an Ultralytics YOLO head pass --task base|seg|pose, --num-classes N and, "
                              "for pose, --kpt-shape K V. Other families: " + PPU_HINT)
    if task == "pose" and not kpt:
        raise Unsupported("pose needs --kpt-shape K V (num_keypoints, values_per_keypoint: 3 = x,y,visibility)")
    extra = {"seg": MASK_CH, "pose": kpt[0] * kpt[1] if kpt else None}.get(task)
    if C is None:
        rest = others - {extra}
        if len(rest) != 1:
            raise Unsupported(f"cannot infer num_classes from head channels {sorted(others)}: pass --num-classes N")
        C = rest.pop()
        notes.append(f"NOTE: num_classes={C} inferred from the class head channels (no 'names' in the ONNX metadata)")

    roles = {"bbox": bbox_ch, "cls_conf": C}
    if task == "seg":
        roles["mask_coeff"] = MASK_CH
    elif task == "pose":
        roles["kpt"] = extra
    if len(set(roles.values())) != len(roles):
        raise Unsupported(f"channel collision {roles}: identify the head Convs in Netron and write the block by hand")

    def pick(cands):  # NMS-free models (YOLO26, YOLOv10) keep both branches: use one2one
        cands = [c for c in cands if "one2one" in c] or cands
        if len(cands) > 1:
            cands = [c for c in cands if gr.reaches_concat(c)] or cands
        return cands

    layers = []
    for s in strides:  # stride order 8 -> 16 -> 32
        layer = {}
        for role, ch in roles.items():
            cands = pick(heads[s].get(ch, []))
            if not cands and role != "bbox" and "bbox" in layer:
                cands = gr.concat_partners(layer["bbox"], ch)
                if len(cands) == 1 and gr.op_of(cands[0]) is None:
                    raise Unsupported(f"stride {s}: the {ch}ch {role} tensor next to the box head is a graph "
                                      f"input or initializer ('{cands[0]}'), not a head output. " + PPU_HINT)
                if len(cands) == 1 and gr.op_of(cands[0]) == "Sigmoid":
                    raise Unsupported(f"stride {s}: the {ch}ch {role} tensor next to the box head is a Sigmoid "
                                      "output; pre_optimize applies Sigmoid itself and needs raw logits. " + PPU_HINT)
                if len(cands) == 1:
                    notes.append(f"NOTE: stride {s} {role} is a {gr.op_of(cands[0])} output, not a Conv")
            if len(cands) != 1:
                raise Unsupported(f"stride {s}: expected 1 {role} Conv with {ch} channels, found {cands}. "
                                  f"Head-like Convs: {found}." + (hint if role == "bbox" else ""))
            layer[role] = cands[0]
        if task == "pose":
            layer["kpt_shape"] = list(kpt)
        layers.append(layer)

    if p == NO_DFL and "one2one" not in layers[0]["bbox"] and str(gr.meta.get("end2end")) != "True":
        raise Unsupported("no-DFL head without a one2one (NMS-free) branch, e.g. the default YOLO26 export "
                          "(end2end=False): its one2many head needs NMS, which yolo_no_dfl_postprocess omits. "
                          "Re-export the NMS-free head (Ultralytics: model.export(format='onnx', nms=False), "
                          "output [1,300,6]) and re-run.")
    for n in notes:
        note(n)
    cfg = {"task": task, "layers": layers, "num_classes": C}
    if args.topk:
        cfg["topk"] = args.topk
    if p == DFL and (str(gr.meta.get("end2end")) == "True" or "one2one" in layers[0]["bbox"]):
        note("WARNING: NMS-free (one2one) model with DFL heads (YOLOv10-style): yolo_dfl_postprocess outputs "
             "[1,4+C,K] candidates instead of the original [1,K,6] detections - adapt the host "
             "post-processing. YOLOv10 is not in the documented support list.")
    if args.num_classes and names and args.num_classes != len(names):
        note(f"WARNING: --num-classes {args.num_classes} != {len(names)} classes in the ONNX metadata")
    return p, cfg, f"task={task}, num_classes={C}, strides {strides}"


def expected_shapes(p, cfg):
    if p == RTM:
        return None
    K = cfg.get("topk", DEFAULT_TOPK[p])
    task = cfg["task"]
    extra = {"base": 0, "seg": MASK_CH}.get(task)
    if extra is None:
        k, v = cfg["layers"][0]["kpt_shape"]
        extra = k * v
    if p == DFL:
        return [1, 4 + cfg["num_classes"] + extra, K]
    return [1, K, 6 + extra]


def ort_run(model, x, extra=()):
    import onnxruntime as ort
    for name in extra:  # expose intermediate tensors
        model.graph.output.append(onnx.ValueInfoProto(name=name))
    so = ort.SessionOptions()
    so.log_severity_level = 4  # quiet: warnings, and run errors that VERIFY FAIL reports anyway
    s = ort.InferenceSession(model.SerializeToString(), so, providers=["CPUExecutionProvider"])
    return s.run(None, {s.get_inputs()[0].name: x})


def detection_table(outs):
    """[1,K,D] detections plus any [1,K] outputs (RTMDet labels) as extra columns; score is column 4."""
    t = next(a[0] for a in outs if a.ndim == 3)
    cols = [a[0][:, None] for a in outs if a.ndim == 2 and a.shape[1] == t.shape[0]]
    return np.concatenate([t] + cols, 1).astype(np.float64)


def compare_rows(o, q, cut):
    """Rows scoring above `cut` must match as a set (equal scores may be reordered, rows at or
    below the cut-off may differ). Cut-off = the K-th original score, or for RTMDet the
    original pre-NMS score at index topk-1 (a smaller topk feeds fewer candidates to NMS).
    Returns ok=None when neither model has a row above the cut-off: nothing was compared."""
    b = max(float(o[:, 4].min()), cut)
    b += 1e-7 + 1e-4 * abs(b)

    def covered(r, ref):
        return (np.abs(ref - r) <= 1e-2 + 1e-3 * np.abs(r)).all(1).any()

    ao, aq = o[o[:, 4] > b], q[q[:, 4] > b]
    head = f"{len(ao)}/{len(o)} original rows score above {b:.3g}: "
    if not len(ao) and not len(aq):  # e.g. untrained weights: every score is at the cut-off
        return None, head + "no row to compare"
    miss = sum(not covered(r, o) for r in aq) + sum(not covered(r, q) for r in ao)
    ok = len(ao) == len(aq) and miss == 0
    return ok, head + ("all match (order-insensitive)" if ok else
                       f"{miss} unmatched, pre_optimize has {len(aq)} rows above")


def compare_dfl(o, q, C):
    """Every pre_optimize candidate must equal an original anchor column with the same score,
    and the kept scores must be the original top-K (ties at the K boundary are allowed)."""
    o, q = o[0], q[0]  # [D, L], [D, K]
    so, sq = o[4:4 + C].max(0), q[4:4 + C].max(0)
    s_err = float(np.abs(np.sort(sq)[::-1] - np.sort(so)[::-1][:q.shape[1]]).max())
    c_err = 0.0
    for j in range(q.shape[1]):
        cand = np.flatnonzero(np.abs(so - sq[j]) <= 1e-5 + 1e-4 * abs(sq[j]))
        if not len(cand):
            return False, f"candidate {j} (score {sq[j]:.4g}) has no matching original anchor"
        err = np.abs(o[:, cand] - q[:, j:j + 1]) / (1e-2 + 1e-3 * np.abs(q[:, j:j + 1]))
        c_err = max(c_err, float(err.max(0).min()))
    ok = s_err < 1e-4 and c_err <= 1.0
    return ok, f"top-K scores max err {s_err:.2g}, columns within tolerance: {c_err <= 1.0}"


def verify(path, p, cfg, gr):
    try:
        import dx_com
    except ImportError:
        note("VERIFY FAIL: dx_com is not installed")
        return False
    try:
        with contextlib.redirect_stdout(sys.stderr):
            opt = dx_com.pre_optimize(onnx.load(path), passes={p: cfg})
    except Exception as e:
        note(f"VERIFY FAIL: dx_com.pre_optimize raised {type(e).__name__}: {e}")
        return False
    outs = [(o.name, dims_of(o)) for o in opt.graph.output]
    note(f"pre_optimize OK -> outputs {outs}")
    exp = expected_shapes(p, cfg)
    if exp and outs[0][1] != exp:
        note(f"VERIFY FAIL: output 0 is {outs[0][1]}, expected {exp} - check pass/task/num_classes/kpt_shape")
        return False
    try:
        d = [x or 1 for x in gr.shape[gr.input.name]]
        dtype = onnx.helper.tensor_dtype_to_np_dtype(gr.input.type.tensor_type.elem_type)
        x = np.random.default_rng(0).random(d).astype(dtype)
        o0 = ort_run(onnx.load(path), x, [cfg["nms_score_tensor"]] if p == RTM else [])
        o1 = ort_run(opt, x)
    except ImportError:
        note("VERIFY UNCHECKED: onnxruntime is not installed - values were NOT compared")
        return None
    except Exception as e:
        note(f"VERIFY FAIL: onnxruntime could not run the models: {e}")
        return False
    cut = 0.0
    if p == RTM:
        pre = o0.pop().ravel()  # original pre-NMS top-k scores, sorted
        cut = float(pre[min(cfg.get("topk", DEFAULT_TOPK[RTM]), pre.size) - 1])
    anchors = p == DFL and sum(gr.shape[l["bbox"]][2] * gr.shape[l["bbox"]][3] for l in cfg["layers"])
    if p == DFL and o0[0].ndim == 3 and o0[0].shape[1] == o1[0].shape[1] and o0[0].shape[2] != anchors:
        note(f"VERIFY FAIL: original output has {o0[0].shape[2]} anchors, the configured layers cover "
             f"{anchors} - a head scale is missing from the config")
        return False
    if p == DFL and o0[0].ndim == 3 and o0[0].shape[2] == anchors:  # raw [1,D,anchors]
        if o0[0].shape[1] != o1[0].shape[1]:
            note(f"VERIFY FAIL: original output has {o0[0].shape[1]} channels per anchor, pre_optimize "
                 f"{o1[0].shape[1]} - check num_classes/task/kpt_shape")
            return False
        ok, msg = compare_dfl(o0[0], o1[0], cfg["num_classes"])
        ok = ok and all(np.allclose(a, b, atol=1e-3) for a, b in zip(o0[1:], o1[1:]))
    elif p != DFL and [a.shape for a in o0] == [b.shape for b in o1] and any(a.ndim == 3 for a in o0):
        ok, msg = compare_rows(detection_table(o0), detection_table(o1), cut)
        rest = [(a, b) for a, b in zip(o0, o1) if a.ndim == 4]  # seg prototypes
        if not all(np.allclose(a, b, atol=1e-3) for a, b in rest):
            ok = False
    else:
        note(f"VERIFY UNCHECKED: original outputs {[a.shape for a in o0]} have another layout - "
             "values were NOT compared; check detections on a real image")
        return None
    if ok is None:
        note(f"VERIFY UNCHECKED: {msg} - values were NOT compared (all scores are at the cut-off, "
             "e.g. untrained weights); verify with the trained model")
        return None
    note(("VERIFY PASS: " if ok else "VERIFY FAIL: ") + msg + " (onnxruntime, random input)")
    return ok


def config_topk(conf):
    """topk of the config being replaced (PPU type 2 or an older pre_optimize block)."""
    old = [conf.get("ppu") or {}] + [c for e in conf.get("pre_optimize") or [] for c in e.values()]
    return next((c["topk"] for c in old if isinstance(c, dict) and "topk" in c), None)


def merge(conf, block, gr):
    inputs = conf.get("inputs")
    if isinstance(inputs, dict) and gr.input.name not in inputs:
        note(f"WARNING: config 'inputs' keys {list(inputs)} do not match the ONNX input name '{gr.input.name}'")
    ppu = conf.pop("ppu", None)
    if ppu is not None:
        note(f"NOTE: removed 'ppu' (type {ppu.get('type')}): ppu and pre_optimize are mutually exclusive; "
             "head names were re-detected from the ONNX."
             + (f" conf_thres={ppu['conf_thres']} has no pre_optimize key - apply it on the host."
                if "conf_thres" in ppu else ""))
    if "pre_optimize" in conf:
        note("NOTE: replaced the existing 'pre_optimize' block")
    conf["pre_optimize"] = block["pre_optimize"]
    return conf


def main():
    try:
        return run()
    except Exception as e:  # anything but Unsupported: distinct from VERIFY FAIL (1)
        note(f"ERROR: {type(e).__name__}: {e}")
        return 3


def run():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("model", help="ONNX model (full model, static input H/W)")
    ap.add_argument("--pass", dest="pass_name", choices=[DFL, NO_DFL, RTM], help="override auto-detection")
    ap.add_argument("--task", choices=["base", "seg", "pose"], help="YOLO task (default: ONNX metadata)")
    ap.add_argument("--num-classes", type=int, help="default: len(metadata names) or class head channels")
    ap.add_argument("--kpt-shape", type=int, nargs=2, metavar=("K", "V"), help="pose: default metadata kpt_shape")
    ap.add_argument("--topk", type=int, help="written when given or kept from --config "
                    "(pass defaults: YOLO 300, RTMDet 512)")
    ap.add_argument("--config", help="existing DX-COM config JSON to merge into")
    ap.add_argument("--verify", action="store_true",
                    help="run dx_com.pre_optimize and compare with the original model in onnxruntime")
    args = ap.parse_args()
    conf = None
    if args.config:
        with open(args.config) as f:
            conf = json.load(f)
        if args.topk is None and config_topk(conf) is not None:
            args.topk = config_topk(conf)
            note(f"NOTE: keeping topk={args.topk} from {args.config} (override with --topk)")
    try:
        gr = Graph(args.model)
        is_rtm = args.pass_name == RTM or (args.pass_name is None and any(
            "rtm_cls" in o for o, _, _ in gr.conv_outputs()))
        p, cfg, info = (build_rtmdet if is_rtm else build_yolo)(gr, args)
    except Unsupported as e:
        note(f"UNSUPPORTED: {e}")
        return 2
    note(f"detected {p}: {info}; input '{gr.input.name}' {gr.shape[gr.input.name]}")
    block = {"pre_optimize": [{p: cfg}]}
    ok = verify(args.model, p, cfg, gr) if args.verify else True
    out = merge(conf, block, gr) if conf is not None else block
    print(json.dumps(out, indent=2))
    return 4 if ok is None else 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
