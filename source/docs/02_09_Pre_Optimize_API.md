# Pre-Optimize API

`dx_com.pre_optimize()` is an ONNX-level transformation that restructures the CPU-side post-processing of a detection, segmentation, or pose model so that expensive operations run only on a small set of TopK candidates. It targets edge environments where CPU performance is limited (for example, ARM cores) and CPU post-processing becomes the end-to-end throughput bottleneck.

There are two ways to apply it:

- **Python API** — call `dx_com.pre_optimize()` on a loaded model, then pass the result to `dx_com.compile()`.
- **Config JSON** — add a `pre_optimize` block to the compile config, and the passes run automatically inside `dx_com.compile()`.

!!! note "When to use"  

    Use `pre_optimize()` when CPU post-processing (Sigmoid, DFL decoding, dist2bbox, NMS pre-filtering, etc.) dominates end-to-end latency. It is most effective for YOLO-family **detection / segmentation / pose** models and **RTMDet** on CPU-constrained hosts.

!!! warning "Replaces PPU Type 2"  

    `pre_optimize()` is the recommended replacement for the deprecated **PPU Type 2** post-processing mode (see [Migration from PPU Type 2](#migration-from-ppu-type-2)). `pre_optimize` and `ppu` are **mutually exclusive** in one config — both rewrite detection post-processing, so supplying both raises a validation error.

---

## How It Works

The detection head of these models runs several operations on the host CPU after NPU inference: Sigmoid, Softmax, DFL decoding, dist2bbox, NMS pre-filtering. When these run over the full anchor grid (for example, 8400 candidates at 640×640), CPU post-processing can dominate latency and leave the NPU idle.

`pre_optimize()` reorders the graph so that:

1. **TopK selection happens first**, narrowing candidates to `K` (default 300).
2. **Expensive operations run only on those `K` candidates**.

CPU post-processing cost then scales with `K` instead of the full anchor count.

---

## Available Passes

| Pass | Target models | Tasks | Output |
|------|---------------|-------|--------|
| `yolo_dfl_postprocess` | YOLOv8 / v9 / v11 / v12 / v13 | detection · segmentation · pose | `[N, 4+C (+mask or +keypoints), K]` |
| `yolo_no_dfl_postprocess` | YOLO26 (NMS-free) | detection · segmentation · pose | `[N, K, 6 (+mask or +keypoints)]` |
| `rtmdet_postprocess` | RTMDet S / M / L / X | detection | NMS tensors (original NMS preserved) |

Notes:

- For **segmentation**, the mask **prototype** output is preserved unchanged.
- Axis layout differs by family: `yolo_dfl_postprocess` puts channels on axis 1 and `K` on axis 2; `yolo_no_dfl_postprocess` puts `K` on axis 1.
- `rtmdet_postprocess` rebuilds only the pre-NMS pipeline; the original NMS and all post-NMS logic stay intact.

!!! info "Changed in v2.5.0"  

    - Passes were **renamed**: `yolo_postprocess` → `yolo_dfl_postprocess`, `yolo26_postprocess` → `yolo_no_dfl_postprocess`. The old names now raise a migration hint.
    - YOLO passes require an explicit **`task`** key (`base` / `seg` / `pose`).
    - **`input_height` / `input_width` are removed** — the input size is derived from the model input. Supplying them raises `ValueError`.
    - New capabilities: **pose** (both YOLO passes), **segmentation on YOLO26** (`yolo_no_dfl_postprocess`), and the new **`rtmdet_postprocess`** pass.

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
| `model` | `onnx.ModelProto` | Yes | Source ONNX model loaded via `onnx.load()`. Must be a **full model** — the network input is used to derive per-scale strides. |
| `passes` | `dict[str, dict]` | Yes | Mapping from pass name to its configuration. Specify exactly one pass per call. |

### Returns

An optimized `onnx.ModelProto`. Pass it directly to `dx_com.compile()` via `model=`, or save it with `onnx.save()`.

### Raises

- `KeyError` — unrecognized pass name (old names raise a migration hint), or a missing required configuration key.
- `ValueError` — a tensor name in `layers` cannot be resolved, or `task` validation fails (missing/unknown `task`, or per-layer keys that are required/forbidden for the chosen `task`).

---

## Configuration Schema

### YOLO passes (`yolo_dfl_postprocess`, `yolo_no_dfl_postprocess`)

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `task` | `str` | **Yes** | `base` (detection), `seg` (segmentation), or `pose` (keypoints). Drives head routing and per-layer key validation. |
| `layers` | `list[dict]` | **Yes** | One entry per detection scale, mapping tensor roles to Conv-head output tensor names. |
| `num_classes` | `int` | `yolo_dfl_postprocess`: **Yes** · `yolo_no_dfl_postprocess`: No (default `80`) | Number of classification classes. |
| `topk` | `int` | No (default `300`) | Candidates to keep after TopK selection. |

Per-layer roles depend on `task`:

| task | required per-layer roles | forbidden roles |
|------|--------------------------|-----------------|
| `base` | `bbox`, `cls_conf` | `mask_coeff`, `kpt` |
| `seg`  | `bbox`, `cls_conf`, `mask_coeff` | `kpt` |
| `pose` | `bbox`, `cls_conf`, `kpt` (+ `kpt_shape`) | `mask_coeff` |

Validation runs before any graph edit and raises a message prefixed with the pass name. For `pose`, `kpt_shape = [num_keypoints, values_per_keypoint]` (e.g. `[17, 3]`) must be identical across scales, and `num_keypoints × values_per_keypoint` must equal the keypoint Conv channel count.

!!! warning "`input_height` / `input_width` removed"  

    These are no longer accepted — the input H/W is always derived from the model input. Supplying them raises `ValueError`.

### RTMDet pass (`rtmdet_postprocess`)

Detection-only — **no `task` key**. Targets RTMDet models exported from [MMDetection](https://github.com/open-mmlab/mmdetection).

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `cls_layers` | `list[str]` | Yes | Classification Conv-head output tensor names, one per scale. |
| `reg_layers` | `list[str]` | Yes | Regression Conv-head output tensor names, one per scale. |
| `use_exp` | `bool` | Yes | `True` if the reg branch applies `Exp`; `False` otherwise. |
| `nms_boxes_tensor` | `str` | Yes | Boxes tensor feeding the original NMS. |
| `nms_scores_tensor` | `str` | Yes | Full per-class score tensor `[1, K, C]` feeding NMS (post-Sigmoid). |
| `nms_score_tensor` | `str` | Yes | Top-K score values tensor (TopK output). |
| `num_classes` | `int` | No (derived from `cls_layers`) | Number of classification classes. |
| `topk` | `int` | No (default `300`) | Candidates to keep after TopK selection. |

---

## Usage — Python API

Load the model, apply exactly one pass, then compile. The tensor names below are the real Conv-head output names from the corresponding modelzoo model (ultralytics export). Find the names for your own model with [Identifying Conv Head Tensor Names](#identifying-conv-head-tensor-names).

### YOLOv8n Detection — `yolo_dfl_postprocess` (`task="base"`)

```python
import onnx
import dx_com

model = onnx.load("yolov8n.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_dfl_postprocess": {
        "task": "base",
        "layers": [
            {"bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0"},
            {"bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0"},
            {"bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
             "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0"},
        ],
        "num_classes": 80,   # required for the DFL pass
        "topk": 300,
    },
})
# Output: [1, 84, 300]   (4 bbox_xywh + 80 cls scores, K = 300)

dx_com.compile(model=optimized, config="yolov8n.json", output_dir="./out")
```

### YOLOv8n Segmentation — `yolo_dfl_postprocess` (`task="seg"`)

```python
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
```

### YOLOv8n Pose — `yolo_dfl_postprocess` (`task="pose"`)

```python
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
```

### YOLO26n Detection — `yolo_no_dfl_postprocess` (`task="base"`)

```python
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
```

### YOLO26n Segmentation — `yolo_no_dfl_postprocess` (`task="seg"`)

```python
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
```

### YOLO26n Pose — `yolo_no_dfl_postprocess` (`task="pose"`)

```python
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
```

### RTMDet-S Detection — `rtmdet_postprocess`

```python
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
```

---

## Usage — Config JSON

Add a `pre_optimize` block to the compile config. It is a **list** holding exactly one single-key `{pass_name: config}` dict — mirroring the Python API `passes={name: cfg}`. `dx_com.compile()` then applies the pass automatically to the raw ONNX before compilation. The pass config is identical to the Python API examples above.

```json
{
  "inputs": { "images": [1, 3, 640, 640] },
  "calibration_num": 100,
  "calibration_method": "ema",
  "default_loader": {
    "dataset_path": "./calibration_images",
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
          {"bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
           "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0"},
          {"bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
           "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0"},
          {"bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
           "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0"}
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

    The optimized graph keeps the **source file name** — the artifact is `<stem>.dxnn`, the same as a normal compile. No graph rename and no extra ONNX dump happen on either the config-JSON path or the direct `ModelProto` API path.

---

## Identifying Conv Head Tensor Names

The `layers` field expects the **output tensor name** of each Conv head (one per detection scale). Locate these with [Netron](https://netron.app) or programmatically:

```python
import onnx
from onnx import shape_inference

model = shape_inference.infer_shapes(onnx.load("model.onnx"))
num_classes = 80  # set to your model's class count (80 = COCO, 1 = single-class, ...)

for node in model.graph.node:
    if node.op_type == "Conv":
        out = node.output[0]
        for vi in model.graph.value_info:
            if vi.name == out:
                dims = [d.dim_value for d in vi.type.tensor_type.shape.dim]
                # 64ch = bbox (DFL), 4ch = bbox (direct), num_classes-ch = cls,
                # 32ch = mask coefficient, nk*vpk-ch = keypoints (e.g. 17*3 = 51)
                if len(dims) == 4 and dims[1] in {4, 32, 51, 64, num_classes}:
                    print(f"{node.name} -> {out}: {dims}")
```

---

## Performance Reference (DEEPX DX-M1, ARM Cortex-A53)

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
DXRT_DYNAMIC_CPU_THREAD=ON run_model -m <model_path> -l 1000 --use-ort
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
      {"bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
       "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0"},
      {"bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
       "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0"},
      {"bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
       "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0"}
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
          {"bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
           "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0"},
          {"bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
           "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0"},
          {"bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
           "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0"}
        ],
        "num_classes": 80,
        "topk": 512
      }
    }
  ]
}
```

**Differences:**

| | PPU Type 2 (previous) | `pre_optimize` (current) |
|--|--|--|
| Configuration location | JSON config file | Python API **or** config-JSON `pre_optimize` block |
| Segmentation support | No | Yes |
| Pose support | No | Yes |
| YOLO26 support | No | Yes (`yolo_no_dfl_postprocess`) |
| RTMDet support | No | Yes (`rtmdet_postprocess`) |
| Pass names | (`ppu.type = 2`) | `yolo_dfl_postprocess` / `yolo_no_dfl_postprocess` / `rtmdet_postprocess` |
| `input_height` / `input_width` | n/a | removed — derived from the model input |

---
