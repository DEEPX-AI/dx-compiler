---
name: dx-agent-compiler-pre-optimize
description: "Use when a user asks about pre_optimize or dx_com.pre_optimize(), needs the head Conv tensor names (bbox, cls_conf, mask_coeff, kpt) of a YOLO or RTMDet ONNX, wants a pre_optimize config block or passes dict, says CPU post-processing (TopK, DFL decode, NMS pre-filter) is the bottleneck, migrates a ppu config to pre_optimize, or hits pre_optimize errors such as 'Cannot find shapes'"
---

# /dx-agent-compiler-pre-optimize — Pre-Optimize Config Skill

> Produce a verified `pre_optimize` config for a YOLO / RTMDet ONNX with one script
> run instead of tracing head Conv names by hand. This skill and the script are all you
> need for that. Read `source/docs/02_09_Pre_Optimize_API.md` only for questions the
> skill does not answer. A complete answer is the verified JSON plus the three host-side
> lines of Phase 3.

## Trigger Words

"pre_optimize", "pre-optimize", "dx_com.pre_optimize", "head tensor names",
"bbox / cls_conf / mask_coeff / kpt", "yolo_dfl_postprocess",
"yolo_no_dfl_postprocess", "rtmdet_postprocess", "PPU type 2", "ppu to pre_optimize",
"post-processing bottleneck", "Cannot find shapes"

## Supported Models

| ONNX model | Pass |
|---|---|
| YOLOv8 / v9 / v11 / v12 / v13 (DFL head, 64-ch bbox): detect, seg, pose | `yolo_dfl_postprocess` |
| YOLO26 (no-DFL head, 4-ch bbox): detect, seg, pose | `yolo_no_dfl_postprocess` |
| RTMDet (MMDetection, exported with NMS): detect | `rtmdet_postprocess` |
| Anchor-based YOLOv3 / v5 / v7 | none: PPU type 0 (`/dx-agent-compiler-compile`) |
| YOLOX (objectness head) | none: PPU type 1 |
| Sigmoid inside the head (YOLOv6, DAMO-YOLO); obb, classify, depth | none |

The script detects the pass and task from the graph. Do not pick them from the model name.

## Phase 1: Generate and Verify

Use the Python environment that has `dx_com`, `onnx` and `onnxruntime`:

```bash
python .deepx/scripts/pre_optimize_find_heads.py model.onnx --verify > pre_optimize.json
```

- stdout is JSON only. `detected …`, `NOTE:`, `WARNING:`, `UNSUPPORTED:` and the verify report go to stderr.
- `task`, `num_classes` and `kpt_shape` come from the Ultralytics ONNX metadata, falling back to head channel counts.
- `--verify` runs `dx_com.pre_optimize` and compares the result with the original model in onnxruntime.
- `topk` is written only with `--topk N` or when kept from `--config`; otherwise the pass
  default applies: 300 for the YOLO passes, 512 for `rtmdet_postprocess`.
- `--pass`, `--task`, `--num-classes` and `--kpt-shape K V` override detection. Use them
  only when the script asks (see Error Recovery).
- Use the script as a black box. Learn its options and behavior from this skill and `--help`,
  not from its source, and rely on `--verify` to check the result. Read the source only when
  debugging the script itself.

**Validation gate**: exit code 0 and `VERIFY PASS` on stderr.

| Exit | Meaning |
|---|---|
| 0 | OK, go to Phase 2 |
| 1 | `VERIFY FAIL`: the JSON is printed but must not be used (see Error Recovery) |
| 2 | Unsupported model, or overrides needed (see Error Recovery) |
| 3 | `ERROR:` the script could not run (bad path, bad config JSON, …): fix the input |
| 4 | `VERIFY UNCHECKED`: values were not compared; do not use the JSON as verified (see Error Recovery) |

## Phase 2: Apply

Config JSON (compile flow): merge into the existing config.

```bash
python .deepx/scripts/pre_optimize_find_heads.py model.onnx --config config.json --verify > config.new.json
```

Every other key is kept. `ppu` is removed, because `ppu` and `pre_optimize` are mutually
exclusive. An existing `topk` is kept unless `--topk N` is given. Then compile as usual
with `/dx-agent-compiler-compile`; `dx_com.compile()` applies the block. In a compile
session, write these files into `dx-agent-dev/<session_id>/`.

Python API (use either this or the config block, not both):

```python
import json, onnx, dx_com
passes = json.load(open("pre_optimize.json"))["pre_optimize"][0]
model = dx_com.pre_optimize(onnx.load("model.onnx"), passes=passes)
```

**Validation gate**: `pre_optimize` is a list of single-key `{pass: cfg}` dicts, and the
config has no `ppu` key. After a compile with the config block, the console (stderr) shows
`[pre_optimize] applying pass '<pass>' from config`. A `falling back to legacy` line instead
means the block was dropped (see Pitfalls). compiler.log records neither line.

## Phase 3: Report

Show the JSON, then end the reply with these three lines filled in for this model, even
when the user asked only for the JSON or listed what the reply must contain. Such a list
says what to include, not what to leave out: put the three lines after the listed items.
Leave them out only when the user explicitly forbids any other text.
Example (YOLOv8n, 80 classes):

```text
Output: preopt_output [1, 84, 300] (was output0 [1, 84, 8400])
Host still does: confidence threshold, NMS
Host code: must change if it parses PPU output or assumes 8400 anchors
```

| Pass | New output | Host still does |
|---|---|---|
| `yolo_dfl_postprocess` | `[1, 4+C (+32 mask / +K×V kpt), topk]`: the original rows (xywh, Sigmoid-ed scores) for the top-K anchors only | threshold, NMS |
| `yolo_no_dfl_postprocess` | `[1, topk, 6 (+…)]`: xyxy, score, class_id | threshold (the model is NMS-free) |
| `rtmdet_postprocess` | the original NMS outputs, unchanged | nothing new; host code needs no change |

- Segmentation keeps the prototype output, and the host still assembles the masks.
- There is no confidence-threshold key (a PPU `conf_thres` is dropped), so filter on the host.

**Validation gate**: the reply ends with the three lines, filled in for this model, after
any items the user listed.

## Error Recovery

| stderr | Action |
|---|---|
| `cannot infer the task` | No metadata. Confirm with the user, then add `--task` (`base`, `seg`, `pose`), plus `--kpt-shape K V` for pose |
| `expected 1 … Conv with N channels, found []` | A wrong override. Re-run without it; the message lists the real head channels |
| `UNSUPPORTED:` … `P2-style model` | Stride-4 head: the passes cover strides 8/16/32. Keep PPU or host post-processing |
| `UNSUPPORTED:` no-DFL head without a one2one branch | Default YOLO26 export (one2many head, needs NMS). Re-export with `nms=False` (output `[1,300,6]`) and re-run |
| `UNSUPPORTED:` anchor-based, YOLOX, Sigmoid in head, obb… | Not supported. Recommend the PPU type named in the message, or host post-processing |
| `VERIFY FAIL: dx_com is not installed` | Switch to the compile environment and re-run |
| other `VERIFY FAIL` | Re-run without overrides. If it still fails, report it; do not hand-edit names |
| `VERIFY UNCHECKED` | Values unchecked: install onnxruntime and re-run; if no row scored above the cut-off (untrained weights), re-run with the trained model; for YOLOv10-style layouts, check on a real image and tell the user it is unverified |
| `WARNING:` | Pass it on to the user |

Never force `--pass` onto a model the script rejects. If the script cannot run, use the
"Identifying Conv Head Tensor Names" section of `source/docs/02_09_Pre_Optimize_API.md`.

## Pitfalls (dx_com 2.5.0)

- Unknown or misspelled keys are silently ignored, and a wrong pass or `num_classes` can
  still convert. Only `--verify` catches these.
- Never put `ppu` and `pre_optimize` in one config. 2.5.0 does not reject it: the conflict shows
  up only as a console line (`falling back to legacy: ValueError: config 'pre_optimize' and 'ppu' are
  mutually exclusive`), and the compile continues with `ppu` alone (`pre_optimize` is dropped) or
  fails later with an unrelated error such as `SurgeonGraphVerificationError`. Treat that error as
  a symptom of the conflict and remove one block instead of debugging it. The Phase 2 `--config`
  merge drops `ppu` from the config for you.
- A `pre_optimize` block that is not a list of single-key `{pass: cfg}` dicts is dropped the same
  way: the console line `falling back to legacy: ValueError: config 'pre_optimize' must be a list …`
  (or `each 'pre_optimize' list item must be a single …`), exit 0, and a model without
  `pre_optimize`. Errors inside a pass, such as a renamed pass, `input_height` / `input_width`
  or `Cannot find shapes`, do stop the compile (exit 1).
- The old pass names `yolo_postprocess` / `yolo26_postprocess` raise a rename error.
- Dynamic input H/W, or `input_height` / `input_width` keys, raise `ValueError`.
- `Cannot find shapes for bbox=…` means a name is not a tensor of this graph: a typo, or
  names copied from a PPU config. PPU type 1 lists node names after the decode/Sigmoid
  (e.g. `/model.22/Sigmoid`), not the head Convs. Re-run the script.
- YOLO `cls_conf` must be the logits Conv; the passes apply Sigmoid themselves.
