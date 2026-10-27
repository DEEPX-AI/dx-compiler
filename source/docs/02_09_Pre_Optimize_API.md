# Pre-Optimize API

`dx_com.pre_optimize()` is an ONNX-level transformation that restructures the CPU-side post-processing of a detection, segmentation, or pose model so that expensive operations run only on a small set of TopK candidates. It targets edge environments where CPU performance is limited (for example, ARM cores) and CPU post-processing becomes the end-to-end throughput bottleneck.

There are two ways to apply it:

- **Python API** — call `dx_com.pre_optimize()` on a loaded model, then pass the result to `dx_com.compile()`.
- **Config JSON** — add a `pre_optimize` block to the compile config, and the passes run automatically inside `dx_com.compile()`.

!!! note "When to use"  

    Use `pre_optimize()` when CPU post-processing (Sigmoid, DFL decoding, dist2bbox, NMS pre-filtering, etc.) dominates end-to-end latency. It is most effective for YOLO-family **detection / segmentation / pose** models and **RTMDet** on CPU-constrained hosts.

!!! warning "Replaces PPU Type 2"  

    `pre_optimize()` is the recommended replacement for the deprecated **PPU Type 2** post-processing mode (see [Migration from PPU Type 2](#migration-from-ppu-type-2)). `pre_optimize` and `ppu` are **mutually exclusive** in one config — both rewrite detection post-processing, so supply only one. DX-COM 2.5.0 does not reject a config that has both: it compiles with `ppu` and drops `pre_optimize`, or fails later with an unrelated error. The only sign is a console line `falling back to legacy: ValueError: config 'pre_optimize' and 'ppu' are mutually exclusive`.

---

## How It Works

The detection head of these models runs several operations on the host CPU after NPU inference: Sigmoid, Softmax, DFL decoding, dist2bbox, NMS pre-filtering. When these run over the full anchor grid (for example, 8400 candidates at 640×640), CPU post-processing can dominate latency and leave the NPU idle.

`pre_optimize()` reorders the graph so that:

1. **TopK selection happens first**, narrowing candidates to `K` (default 300; 512 for RTMDet).
2. **Expensive operations run only on those `K` candidates**.

CPU post-processing cost then scales with `K` instead of the full anchor count.

---

## Available Passes

| Pass | Target models | Tasks | Output |
|------|---------------|-------|--------|
| `yolo_dfl_postprocess` | YOLOv8 / v9 / v11 / v12 / v13 | detection · segmentation · pose | `[1, 4+C (+mask or +keypoints), K]` |
| `yolo_no_dfl_postprocess` | YOLO26 (NMS-free) | detection · segmentation · pose | `[1, K, 6 (+mask or +keypoints)]` |
| `rtmdet_postprocess` | RTMDet S / M / L / X | detection | NMS tensors (original NMS preserved) |

Notes:

- For **segmentation**, the mask **prototype** output is preserved unchanged.
- Axis layout differs by family: `yolo_dfl_postprocess` puts channels on axis 1 and `K` on axis 2; `yolo_no_dfl_postprocess` puts `K` on axis 1.
- Box format also differs: `yolo_dfl_postprocess` outputs `xywh` (center x, center y, width, height) followed by per-class scores; `yolo_no_dfl_postprocess` outputs `xyxy` (top-left, bottom-right) followed by a single score and `class_id`.
- `rtmdet_postprocess` rebuilds only the pre-NMS pipeline; the original NMS and all post-NMS logic stay intact.

!!! info "Changed in v2.5.0"  

    Passes were **renamed**: `yolo_postprocess` → `yolo_dfl_postprocess`, `yolo26_postprocess` → `yolo_no_dfl_postprocess`. The old names now raise a migration hint.

    YOLO passes require an explicit **`task`** key (`base` / `seg` / `pose`).

    **`input_height` / `input_width` are removed** — the input size is derived from the model input. Supplying them raises `ValueError`.
    
    New capabilities: **pose** (both YOLO passes), **segmentation on YOLO26** (`yolo_no_dfl_postprocess`), and the new **`rtmdet_postprocess`** pass.

---

## API Reference

### Signature

```python
dx_com.pre_optimize(
    model: onnx.ModelProto,
    passes: dict[str, dict],
) -> onnx.ModelProto
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `model` | `onnx.ModelProto` | **Yes** | Source ONNX model loaded via `onnx.load()`. Must be a **full model** — the network input is used to derive per-scale strides. |
| `passes` | `dict[str, dict]` | **Yes** | Mapping from pass name to its configuration. Passes are applied in the given order. |

### Returns

An optimized `onnx.ModelProto`. Pass it directly to `dx_com.compile()` via `model=`, or save it with `onnx.save()`.

### Raises

- `KeyError` — unrecognized pass name (old names raise a migration hint), or a missing required configuration key.
- `ValueError` — a tensor name in `layers` cannot be resolved, or `task` validation fails (missing/unknown `task`, or per-layer keys that are required/forbidden for the chosen `task`).

---

## Configuration Schema

### YOLO passes

`yolo_dfl_postprocess` and `yolo_no_dfl_postprocess` target YOLO models exported from [Ultralytics](https://github.com/ultralytics/ultralytics). Both take the fields below:

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `task` | `str` | **Yes** | `base` (detection), `seg` (segmentation), or `pose` (keypoints). Drives head routing and per-layer key validation. |
| `layers` | `list[dict]` | **Yes** | One entry per detection scale, mapping tensor roles to Conv-head output tensor names. Entries **must be ordered by stride: 8, 16, 32** (80×80, 40×40, 20×20 at a 640×640 input). |
| `num_classes` | `int` | `yolo_dfl_postprocess`: **Yes**<br>`yolo_no_dfl_postprocess`: No (default `80`) | Number of classification classes. |
| `topk` | `int` | No (default `300`) | Candidates to keep after TopK selection. |

Roles in each `layers` entry:

| Role | Description |
|------|-------------|
| `bbox` | Output of the box-regression head Conv: the distances from each anchor point to the four box sides, as 16-bin distributions (`yolo_dfl_postprocess`) or as direct values (`yolo_no_dfl_postprocess`).<br>e.g. `/model.22/cv2.0/cv2.0.2/Conv_output_0` (YOLOv8n-seg) |
| `cls_conf` | Output of the classification head Conv: one score per class, as logits before Sigmoid.<br>e.g. `/model.22/cv3.0/cv3.0.2/Conv_output_0` (YOLOv8n-seg) |
| `mask_coeff` | Output of the mask-coefficient head Conv: 32 coefficients that combine the prototype masks into each instance mask.<br>e.g. `/model.22/cv4.0/cv4.0.2/Conv_output_0` (YOLOv8n-seg) |
| `kpt` | Output of the keypoint head Conv, with `num_keypoints × values_per_keypoint` channels (see `kpt_shape`).<br>e.g. `/model.22/cv4.0/cv4.0.2/Conv_output_0` (YOLOv8n-pose, 17 × 3 = 51 channels) |
| `kpt_shape` | Keypoint layout `[num_keypoints, values_per_keypoint]`. `values_per_keypoint` is `3` (x, y, visibility), or `2` (x, y) when the model has no visibility output. Ultralytics exports store it in the ONNX metadata as `kpt_shape`.<br>e.g. `[17, 3]` (COCO keypoints) |

Per-layer roles depend on `task`:

| task | required per-layer roles | forbidden roles |
|------|--------------------------|-----------------|
| `base` | `bbox`, `cls_conf` | `mask_coeff`, `kpt` |
| `seg`  | `bbox`, `cls_conf`, `mask_coeff` | `kpt` |
| `pose` | `bbox`, `cls_conf`, `kpt` (+ `kpt_shape`) | `mask_coeff` |

Validation runs before any graph edit and raises a message prefixed with the pass name. For `pose`, `kpt_shape` must be identical across scales, and `num_keypoints × values_per_keypoint` must equal the keypoint Conv channel count.

### RTMDet pass

`rtmdet_postprocess` is detection-only — **no `task` key**. It targets RTMDet models exported from [MMDetection](https://github.com/open-mmlab/mmdetection).

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `cls_layers` | `list[str]` | **Yes** | Classification Conv-head output tensor names, one per scale. |
| `reg_layers` | `list[str]` | **Yes** | Regression Conv-head output tensor names, one per scale. |
| `use_exp` | `bool` | **Yes** | `True` if the reg branch applies `Exp`; `False` otherwise. |
| `nms_boxes_tensor` | `str` | **Yes** | Boxes tensor feeding the original NMS. |
| `nms_scores_tensor` | `str` | **Yes** | Full per-class score tensor `[1, M, C]` (M = candidates kept by the model's own first `TopK`, e.g. 5000) feeding NMS (post-Sigmoid). |
| `nms_score_tensor` | `str` | **Yes** | Top-K score values tensor (TopK output). |
| `num_classes` | `int` | No (derived from `cls_layers`) | Number of classification classes. |
| `topk` | `int` | No (default `512`) | Candidates to keep after TopK selection. |

---

## Usage

### Python API

Load the model, apply the pass, then compile. The tensor names below are the real Conv-head output names from models exported with Ultralytics (YOLO) and MMDetection (RTMDet). Find the names for your own model with [Identifying Conv Head Tensor Names](#identifying-conv-head-tensor-names).

!!! warning "Example tensor names"  

    Auto-generated names such as `onnx::Concat_328` are specific to one export. They change with the exporter version, export options, and opset. Do not copy them. Look up the names in your own ONNX file with the [script](#find-them-with-a-script-yolo).

#### YOLOv8n Detection

```python
import onnx
import dx_com

model = onnx.load("yolov8n.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_dfl_postprocess": {
        "task": "base",
        "layers": [
            {"bbox": "onnx::Concat_328",
             "cls_conf": "onnx::Concat_335"},
            {"bbox": "onnx::Concat_343",
             "cls_conf": "onnx::Concat_350"},
            {"bbox": "onnx::Concat_358",
             "cls_conf": "onnx::Concat_365"},
        ],
        "num_classes": 80,   # required for the DFL pass
        "topk": 300,
    },
})
# Output: [1, 84, 300]   (4 bbox_xywh + 80 cls scores, K = 300)

dx_com.compile(model=optimized, config="yolov8n.json", output_dir="./out")
```

#### YOLOv8n Segmentation

```python
import onnx
import dx_com

model = onnx.load("yolov8n-seg.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_dfl_postprocess": {
        "task": "seg",
        "layers": [
            {"bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0",
             "mask_coeff": "/model.22/cv4.0/cv4.0.2/Conv_output_0"},
            {"bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0",
             "mask_coeff": "/model.22/cv4.1/cv4.1.2/Conv_output_0"},
            {"bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0",
             "mask_coeff": "/model.22/cv4.2/cv4.2.2/Conv_output_0"},
        ],
        "num_classes": 80,
        "topk": 300,
    },
})
# Output 0: [1, 116, 300]        (4 bbox + 80 cls + 32 mask_coeff, K = 300)
# Output 1: [1, 32, 160, 160]    (mask prototype, preserved unchanged)

dx_com.compile(model=optimized, config="yolov8n-seg.json", output_dir="./out")
```

#### YOLOv8n Pose

```python
import onnx
import dx_com

model = onnx.load("yolov8n-pose.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_dfl_postprocess": {
        "task": "pose",
        "layers": [
            {"bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0",
             "kpt": "/model.22/cv4.0/cv4.0.2/Conv_output_0", "kpt_shape": [17, 3]},
            {"bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0",
             "kpt": "/model.22/cv4.1/cv4.1.2/Conv_output_0", "kpt_shape": [17, 3]},
            {"bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0",
             "kpt": "/model.22/cv4.2/cv4.2.2/Conv_output_0", "kpt_shape": [17, 3]},
        ],
        "num_classes": 1,
        "topk": 300,
    },
})
# Output: [1, 56, 300]   (4 bbox + 1 cls + 17*3 kpt, K = 300)

dx_com.compile(model=optimized, config="yolov8n-pose.json", output_dir="./out")
```

#### YOLO26n Detection

```python
import onnx
import dx_com

model = onnx.load("yolo26n.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_no_dfl_postprocess": {
        "task": "base",
        "layers": [
            {"bbox": "/model.23/one2one_cv2.0/one2one_cv2.0.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.0/one2one_cv3.0.2/Conv_output_0"},
            {"bbox": "/model.23/one2one_cv2.1/one2one_cv2.1.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.1/one2one_cv3.1.2/Conv_output_0"},
            {"bbox": "/model.23/one2one_cv2.2/one2one_cv2.2.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.2/one2one_cv3.2.2/Conv_output_0"},
        ],
        "num_classes": 80,   # optional — defaults to 80 for the no-DFL pass
        "topk": 300,
    },
})
# Output: [1, 300, 6]   (bbox_xyxy + score + class_id, K = 300)

dx_com.compile(model=optimized, config="yolo26n.json", output_dir="./out")
```

#### YOLO26n Segmentation

```python
import onnx
import dx_com

model = onnx.load("yolo26n-seg.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_no_dfl_postprocess": {
        "task": "seg",
        "layers": [
            {"bbox": "/model.23/one2one_cv2.0/one2one_cv2.0.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.0/one2one_cv3.0.2/Conv_output_0",
             "mask_coeff": "/model.23/one2one_cv4.0/one2one_cv4.0.2/Conv_output_0"},
            {"bbox": "/model.23/one2one_cv2.1/one2one_cv2.1.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.1/one2one_cv3.1.2/Conv_output_0",
             "mask_coeff": "/model.23/one2one_cv4.1/one2one_cv4.1.2/Conv_output_0"},
            {"bbox": "/model.23/one2one_cv2.2/one2one_cv2.2.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.2/one2one_cv3.2.2/Conv_output_0",
             "mask_coeff": "/model.23/one2one_cv4.2/one2one_cv4.2.2/Conv_output_0"},
        ],
        "num_classes": 80,
        "topk": 300,
    },
})
# Output 0: [1, 300, 38]         (bbox_xyxy + score + class_id + 32 mask_coeff, K = 300)
# Output 1: [1, 32, 160, 160]    (mask prototype, preserved unchanged)

dx_com.compile(model=optimized, config="yolo26n-seg.json", output_dir="./out")
```

#### YOLO26n Pose

```python
import onnx
import dx_com

model = onnx.load("yolo26n-pose.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_no_dfl_postprocess": {
        "task": "pose",
        "layers": [
            {"bbox": "/model.23/one2one_cv2.0/one2one_cv2.0.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.0/one2one_cv3.0.2/Conv_output_0",
             "kpt": "/model.23/one2one_cv4_kpts.0/Conv_output_0", "kpt_shape": [17, 3]},
            {"bbox": "/model.23/one2one_cv2.1/one2one_cv2.1.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.1/one2one_cv3.1.2/Conv_output_0",
             "kpt": "/model.23/one2one_cv4_kpts.1/Conv_output_0", "kpt_shape": [17, 3]},
            {"bbox": "/model.23/one2one_cv2.2/one2one_cv2.2.2/Conv_output_0",
             "cls_conf": "/model.23/one2one_cv3.2/one2one_cv3.2.2/Conv_output_0",
             "kpt": "/model.23/one2one_cv4_kpts.2/Conv_output_0", "kpt_shape": [17, 3]},
        ],
        "num_classes": 1,
        "topk": 300,
    },
})
# Output: [1, 300, 57]   (bbox_xyxy + score + class_id + 17*3 kpt, K = 300)

dx_com.compile(model=optimized, config="yolo26n-pose.json", output_dir="./out")
```

#### RTMDet-S Detection

```python
import onnx
import dx_com

model = onnx.load("rtmdet-s.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "rtmdet_postprocess": {
        "cls_layers": [
            "/bbox_head/rtm_cls.0/Conv_output_0",
            "/bbox_head/rtm_cls.1/Conv_output_0",
            "/bbox_head/rtm_cls.2/Conv_output_0",
        ],
        "reg_layers": [
            "/bbox_head/rtm_reg.0/Conv_output_0",
            "/bbox_head/rtm_reg.1/Conv_output_0",
            "/bbox_head/rtm_reg.2/Conv_output_0",
        ],
        "use_exp": False,               # True for models whose reg branch has Exp (e.g. rtmdet-m)
        "nms_boxes_tensor": "/Gather_6_output_0",
        "nms_scores_tensor": "/Gather_7_output_0",
        "nms_score_tensor": "/TopK_output_0",
        "topk": 512,
        # num_classes optional — derived from cls layer channels if omitted
    },
})
# NMS and all post-NMS logic preserved; only the pre-NMS pipeline is rebuilt.

dx_com.compile(model=optimized, config="rtmdet-s.json", output_dir="./out")
```

### Config JSON

Add a `pre_optimize` block to the compile config. It is a **list** of single-key `{pass_name: config}` dicts, applied in order — mirroring the Python API `passes={name: cfg}`. `dx_com.compile()` then applies the passes automatically to the raw ONNX before compilation. The pass config is identical to the Python API examples above.

```json
{
  "inputs": { "images": [1, 3, 640, 640] },
  "calibration_num": 100,
  "calibration_method": "ema",
  "default_loader": {
    "dataset_path": "./calibration_dataset",
    "preprocessings": [
      {"resize": {"width": 640, "height": 640}},
      {"div": {"x": 255.0}},
      {"convertColor": {"form": "BGR2RGB"}},
      {"transpose": {"axis": [2, 0, 1]}},
      {"expandDim": {"axis": 0}}
    ]
  },
  "pre_optimize": [
    {
      "yolo_dfl_postprocess": {
        "task": "base",
        "layers": [
          {"bbox": "onnx::Concat_328",
           "cls_conf": "onnx::Concat_335"},
          {"bbox": "onnx::Concat_343",
           "cls_conf": "onnx::Concat_350"},
          {"bbox": "onnx::Concat_358",
           "cls_conf": "onnx::Concat_365"}
        ],
        "num_classes": 80,
        "topk": 300
      }
    }
  ]
}
```

For other tasks/models, swap the `pre_optimize` block for the matching pass config above (`seg` adds `mask_coeff`, `pose` adds `kpt` + `kpt_shape`, `rtmdet_postprocess` uses `cls_layers` / `reg_layers` / `use_exp` / `nms_*_tensor`). Then compile as usual — the pass runs inside compile:

```python
dx_com.compile(model="yolov8n.onnx", config="config.json", output_dir="./out")
```

!!! note "Output artifact"  

    The optimized graph keeps the **source file name** — the artifact is `<stem>.dxnn`, the same as a normal compile. On the file-path entry the graph name is set to the source file stem; a directly-passed `ModelProto` is left unchanged. No extra ONNX dump is written.

---

## Identifying Conv Head Tensor Names

Every YOLO pass needs a `layers` list. It has one entry per detection scale, and each entry maps a **role** to the **output tensor name of the last Conv** in that head branch. That Conv output is the raw head output, before any Sigmoid, DFL, or box decoding. `pre_optimize` takes the graph apart at these tensors and rebuilds the post-processing after them.

Tensor names depend on the model and on the exporter version, so always look them up in your own model. Do not copy names from another model.

### How to recognize a head Conv

A head Conv meets all of the following:

1. **It is the last Conv of its branch.** No activation (Sigmoid, SiLU, Mul) follows it. Its output feeds only `Concat`, `Reshape`, or `Transpose`.
2. **Its output is 4D, `[1, C, H/s, W/s]`, with stride `s` = 8, 16, or 32.**
3. **Its channel count `C` matches a role:**
    - `bbox`: `64` (4 sides × 16 DFL bins) for `yolo_dfl_postprocess`, `4` for `yolo_no_dfl_postprocess`
    - `cls_conf`: `num_classes`
    - `mask_coeff`: `32`
    - `kpt`: `num_keypoints × values_per_keypoint` (e.g. 17 × 3 = 51)

Two Convs look similar but are **not** heads, and the script skips them:

- The DFL Conv (1 channel, after a Softmax), which decodes the 64 bbox channels.
- The segmentation **prototype** Conv (32 channels at stride 4, e.g. 160×160). It has the same channel count as `mask_coeff` but a different resolution, and `pre_optimize` keeps it unchanged.

Notes:

- Use the YOLO26 **`one2one_*`** branches (the NMS-free head), not the `one2many` training branches, if both exist in the graph.
- If the model has no `kpt_shape` metadata, read it from the `Reshape` that follows the `Concat` of the three `kpt` outputs: its target shape is `[1, num_keypoints, values_per_keypoint, -1]`, e.g. `[1, 17, 3, -1]`.

### Find them with a script (YOLO)

The script below scans the model and prints a ready-to-use `pre_optimize` config-JSON block. For Ultralytics exports it reads `task`, the class count, and `kpt_shape` from the ONNX metadata, so in most cases you only set `MODEL` and `PASS`.

```python
import ast
import json
from collections import defaultdict

import onnx
from onnx import shape_inference

# ---- set these for your model ----
MODEL = "model.onnx"
PASS = "yolo_dfl_postprocess"  # YOLOv8/v9/v11/v12/v13; "yolo_no_dfl_postprocess" for YOLO26
# None = read from the Ultralytics ONNX metadata
TASK = None                    # "base" | "seg" | "pose"
NUM_CLASSES = None             # 80 = COCO, 1 = single-class (e.g. person pose)
KPT_SHAPE = None               # pose: [num_keypoints, values_per_keypoint], e.g. [17, 3]
MASK_CH = 32                   # seg: mask coefficient channels
# ----------------------------------

model = shape_inference.infer_shapes(onnx.load(MODEL))
g = model.graph
meta = {p.key: p.value for p in model.metadata_props}


def from_meta(key):
    assert key in meta, f"'{key}' is not in the ONNX metadata: set it manually above"
    return meta[key] if key == "task" else ast.literal_eval(meta[key])


if TASK is None:
    TASK = {"detect": "base", "segment": "seg", "pose": "pose"}.get(from_meta("task"))
    assert TASK, f"unsupported task '{meta['task']}'"
if NUM_CLASSES is None:
    NUM_CLASSES = len(from_meta("names"))
if TASK == "pose" and KPT_SHAPE is None:
    KPT_SHAPE = list(from_meta("kpt_shape"))

shape = {v.name: [d.dim_value for d in v.type.tensor_type.shape.dim]
         for v in list(g.input) + list(g.value_info) + list(g.output)}
consumers = defaultdict(set)
for n in g.node:
    for i in n.input:
        consumers[i].add(n.op_type)

# Channel count of each head Conv, per task
roles = {"bbox": 64 if PASS == "yolo_dfl_postprocess" else 4, "cls_conf": NUM_CLASSES}
if TASK == "seg":
    roles["mask_coeff"] = MASK_CH
elif TASK == "pose":
    roles["kpt"] = KPT_SHAPE[0] * KPT_SHAPE[1]
assert len(set(roles.values())) == len(roles), f"channel collision {roles}: pick heads in Netron"

# Head Conv = 4D output on an FPN scale (stride 8/16/32) with no activation after it
in_h = shape[g.input[0].name][2]
assert in_h, "input H is dynamic: re-export the model with a fixed input size"
heads = defaultdict(lambda: defaultdict(list))  # stride -> channels -> [tensor names]
for n in g.node:
    out = n.output[0]
    d = shape.get(out)
    if n.op_type != "Conv" or not d or len(d) != 4 or not d[2] or in_h % d[2]:
        continue
    stride, ops = in_h // d[2], consumers[out]
    if stride in (8, 16, 32) and ops <= {"Concat", "Reshape", "Transpose"}:
        heads[stride][d[1]].append(out)
assert heads, "no head Conv found: check PASS and the model input"

layers = []
for stride in sorted(heads):  # layers must be in stride order (8 -> 16 -> 32)
    layer = {}
    for role, ch in roles.items():
        names = heads[stride].get(ch, [])
        assert len(names) == 1, f"stride {stride}: expected 1 {role} Conv ({ch}ch), got {names}"
        layer[role] = names[0]
    if TASK == "pose":
        layer["kpt_shape"] = KPT_SHAPE
    layers.append(layer)

cfg = {"task": TASK, "layers": layers, "num_classes": NUM_CLASSES}
print(json.dumps({"pre_optimize": [{PASS: cfg}]}, indent=2))
# Python API: dx_com.pre_optimize(onnx.load(MODEL), passes={PASS: cfg})
```

Settings for each model family and task are listed below. Set only `MODEL` and `PASS` when the model has Ultralytics metadata. Set the other values too when it does not (for example, a model re-exported by another tool).

**YOLOv8 / v11 · det**

```python
PASS = "yolo_dfl_postprocess"
TASK = "base"
NUM_CLASSES = 80
```

Each layer gets `bbox` (64ch) and `cls_conf` (80ch).

**YOLOv8 / v11 · seg**

```python
PASS = "yolo_dfl_postprocess"
TASK = "seg"
NUM_CLASSES = 80
```

Each layer gets `bbox` (64ch), `cls_conf` (80ch), and `mask_coeff` (32ch). The 32ch prototype Conv at stride 4 is skipped.

**YOLOv8 / v11 · pose**

```python
PASS = "yolo_dfl_postprocess"
TASK = "pose"
NUM_CLASSES = 1
KPT_SHAPE = [17, 3]
```

Each layer gets `bbox` (64ch), `cls_conf` (1ch), `kpt` (51ch), and `kpt_shape`.

**YOLO26 · det**

```python
PASS = "yolo_no_dfl_postprocess"
TASK = "base"
NUM_CLASSES = 80
```

Each layer gets `bbox` (4ch) and `cls_conf` (80ch).

**YOLO26 · seg**

```python
PASS = "yolo_no_dfl_postprocess"
TASK = "seg"
NUM_CLASSES = 80
```

Each layer gets `bbox` (4ch), `cls_conf` (80ch), and `mask_coeff` (32ch). The 32ch prototype Conv at stride 4 is skipped.

**YOLO26 · pose**

```python
PASS = "yolo_no_dfl_postprocess"
TASK = "pose"
NUM_CLASSES = 1
KPT_SHAPE = [17, 3]
```

Each layer gets `bbox` (4ch), `cls_conf` (1ch), `kpt` (51ch), and `kpt_shape`.

The output for the YOLOv8n detection model in this guide is:

```json
{
  "pre_optimize": [
    {
      "yolo_dfl_postprocess": {
        "task": "base",
        "layers": [
          {"bbox": "onnx::Concat_328", "cls_conf": "onnx::Concat_335"},
          {"bbox": "onnx::Concat_343", "cls_conf": "onnx::Concat_350"},
          {"bbox": "onnx::Concat_358", "cls_conf": "onnx::Concat_365"}
        ],
        "num_classes": 80
      }
    }
  ]
}
```

Paste it into the compile config as is, or pass `cfg` to `dx_com.pre_optimize()`. `topk` is not printed; add it to change the default of 300. If the script stops with an `AssertionError`, the message tells which value to check: usually `NUM_CLASSES` (no `cls_conf` Conv found) or `PASS` (no `bbox` Conv found).

### Find them in Netron

1. Netron shows tensor shapes only if they are stored in the model. Save a copy with shapes first:

    ```python
    import onnx
    from onnx import shape_inference
    onnx.save(shape_inference.infer_shapes(onnx.load("model.onnx")), "model_shapes.onnx")
    ```

2. Open `model_shapes.onnx` in [Netron](https://netron.app) and scroll to the end of the graph, where the head branches merge into the output.
3. For each scale, follow the parallel branches upward from the `Concat` that joins them. The first `Conv` you reach on each branch is a head Conv. It has no Sigmoid or SiLU after it.
4. Click the Conv. The right panel shows its **output name** (copy this into `layers`) and its shape `[1, C, H, W]`. Use `C` to get the role (channel counts in step 3 of *How to recognize a head Conv*), and `H` to get the scale.

### RTMDet (`rtmdet_postprocess`)

The script below finds all six keys of the [RTMDet pass](#rtmdet-pass) for an MMDetection RTMDet export with NMS in the graph:

```python
import json
from collections import defaultdict

import onnx
from onnx import shape_inference

MODEL = "rtmdet.onnx"

model = shape_inference.infer_shapes(onnx.load(MODEL))
g = model.graph
shape = {v.name: [d.dim_value for d in v.type.tensor_type.shape.dim]
         for v in list(g.input) + list(g.value_info) + list(g.output)}
producer = {o: n for n in g.node for o in n.output}
consumers = defaultdict(list)
for n in g.node:
    for i in n.input:
        consumers[i].append(n.op_type)

in_h = shape[g.input[0].name][2]
assert in_h, "input H is dynamic: re-export the model with a fixed input size"
cls_layers, reg_layers = [], []
for n in g.node:
    out = n.output[0]
    d = shape.get(out)
    if n.op_type != "Conv" or not d or len(d) != 4 or not d[2]:
        continue
    if "rtm_cls" in out:
        cls_layers.append((in_h // d[2], out))
    elif "rtm_reg" in out:
        reg_layers.append((in_h // d[2], out))
assert cls_layers and len(cls_layers) == len(reg_layers), f"cls={cls_layers} reg={reg_layers}"

nms = [n for n in g.node if n.op_type == "NonMaxSuppression"]
assert nms, "no NonMaxSuppression in the graph: export the model with NMS"
scores_t = producer[nms[0].input[1]]
assert scores_t.op_type == "Transpose", f"unexpected NMS score producer: {scores_t.op_type}"
topk = next(n for n in g.node if n.op_type == "TopK")  # the first TopK, over all anchors

cfg = {
    "cls_layers": [o for _, o in sorted(cls_layers)],  # stride 8 -> 16 -> 32
    "reg_layers": [o for _, o in sorted(reg_layers)],
    "use_exp": "Exp" in consumers[reg_layers[0][1]],  # Exp (not Mul) after rtm_reg
    "nms_boxes_tensor": nms[0].input[0],
    "nms_scores_tensor": scores_t.input[0],
    "nms_score_tensor": topk.output[0],
}
print(json.dumps({"pre_optimize": [{"rtmdet_postprocess": cfg}]}, indent=2))
```

For RTMDet-S it prints the same values as the *RTMDet-S Detection* example above. RTMDet-M differs only in `"use_exp": true`.

---

## Performance Reference

Throughput on DEEPX DX-M1 with an ARM Cortex-A53 host CPU:

| Group | Model | Task | Before (FPS) | After (FPS) | Speed-up |
|-------|-------|------|---:|---:|---:|
| `yolo_dfl_postprocess` | YOLOv8n | det  | 89.53 | 355.73 | **4.0×** |
|  | YOLOv8n | seg  | 63.81 | 209.69 | **3.3×** |
|  | YOLOv8n | pose | 268.98 | 400.59 | **1.5×** |
| `yolo_no_dfl_postprocess` | YOLO26n | det  | 184.89 | 315.73 | **1.7×** |
|  | YOLO26n | seg  | 130.82 | 195.05 | **1.5×** |
|  | YOLO26n | pose | 242.77 | 304.38 | **1.3×** |
| `rtmdet_postprocess` | RTMDet-S (score_threshold = 0.3) | det | 156.56 | 290.16 | **1.9×** |

Measured with:

```bash
DXRT_DYNAMIC_CPU_THREAD=ON dxrun -m <model_path> -l 1000 --use-ort
```

End-to-end throughput improves because CPU post-processing is no longer the bottleneck on CPU-constrained hosts.

---

## Migration from PPU Type 2

If you previously used `ppu.type = 2` in the JSON config, switch to `pre_optimize` — either the API or the config-JSON block.

**Previous (deprecated):**

```json
{
  "ppu": {
    "type": 2,
    "topk": 512,
    "num_classes": 80,
    "layer": [
      {"bbox": "onnx::Concat_328",
       "cls_conf": "onnx::Concat_335"},
      {"bbox": "onnx::Concat_343",
       "cls_conf": "onnx::Concat_350"},
      {"bbox": "onnx::Concat_358",
       "cls_conf": "onnx::Concat_365"}
    ]
  }
}
```

**New (`pre_optimize`):**

```json
{
  "pre_optimize": [
    {
      "yolo_dfl_postprocess": {
        "task": "base",
        "layers": [
          {"bbox": "onnx::Concat_328",
           "cls_conf": "onnx::Concat_335"},
          {"bbox": "onnx::Concat_343",
           "cls_conf": "onnx::Concat_350"},
          {"bbox": "onnx::Concat_358",
           "cls_conf": "onnx::Concat_365"}
        ],
        "num_classes": 80,
        "topk": 512
      }
    }
  ]
}
```

!!! note "Reusing PPU layer names"  

    A PPU `layer` entry can be reused as a `layers` entry only if both refer to the same ONNX file and each name is a raw head Conv output. If you re-export the model, the names can change. The `onnx::Concat_NNN` names above are examples. Look up the names again with the [script](#find-them-with-a-script-yolo).

**Differences:**

| | PPU Type 2 (previous) | `pre_optimize` (current) |
|--|--|--|
| Configuration location | JSON config file | Python API **or** config-JSON `pre_optimize` block |
| Segmentation support | No | Yes |
| Pose support | No | Yes |
| YOLO26 support | No | Yes (`yolo_no_dfl_postprocess`) |
| RTMDet support | No | Yes (`rtmdet_postprocess`) |
| Pass names | (`ppu.type = 2`) | `yolo_dfl_postprocess` / `yolo_no_dfl_postprocess` / `rtmdet_postprocess` |

---
