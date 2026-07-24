# Pre-Optimize API

`dx_com.pre_optimize()` is an ONNX-level transformation API that restructures the CPU-side post-processing of a model so that expensive operations are applied only to a small set of TopK candidates. It is intended for edge environments where CPU performance is limited (for example, ARM cores) and CPU post-processing becomes a bottleneck for end-to-end throughput.

!!! note "When to use"

    Use `pre_optimize()` when CPU post-processing (Sigmoid, DFL decoding, dist2bbox, NMS pre-filtering, etc.) becomes a bottleneck for end-to-end inference throughput. It is most effective for YOLO-family detection / instance-segmentation models on CPU-constrained hosts.

!!! warning "Replaces PPU Type 2"

    `pre_optimize()` is the recommended replacement for the deprecated **PPU Type 2** post-processing mode. See [Migration from PPU Type 2](#migration-from-ppu-type-2) below. PPU Type 2 will be removed in a future release.

---

## Overview

The detection head of YOLO-family models contains operations that run on the host CPU after the NPU has finished inference: Sigmoid, Softmax, DFL decoding, dist2bbox, and so on. When these operations run over the full set of anchor candidates (for example, 8400 candidates for a 640×640 input), CPU post-processing can dominate the end-to-end latency and leave the NPU idle while waiting for the next frame.

`pre_optimize()` reorders the post-processing graph so that:

1. **TopK selection happens first**, narrowing the candidate set to `K` (default 300).
2. **Expensive operations run only on those `K` candidates**, instead of the full anchor grid.

The result is a model whose CPU post-processing cost is roughly proportional to `K` rather than to the full anchor count.

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
| `model` | `onnx.ModelProto` | Yes | Source ONNX model loaded via `onnx.load()`. |
| `passes` | `dict[str, dict]` | Yes | Mapping from pass name to its configuration. See [Available Passes](#available-passes). Specify exactly one pass per call. |

### Returns

An optimized `onnx.ModelProto` with the original CPU post-processing replaced by the TopK-first equivalent. The returned model can be passed directly to `dx_com.compile()` via the `model` argument, or saved with `onnx.save()`.

### Raises

- `KeyError` — if the pass name is not recognized, or if a required pass configuration key is missing. See the schema below for which keys are required vs. optional.
- `ValueError` — if a tensor name in `layers` cannot be resolved in the model graph.

### `passes` Configuration Schema

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `layers` | `list[dict]` | Yes | One entry per detection scale. Each entry maps tensor roles (`bbox`, `cls_conf`, `mask_coeff`) to the Conv-head output tensor name. |
| `num_classes` | `int` | Yes | Number of classification classes. |
| `topk` | `int` | No (default `300`) | Number of candidates to keep after TopK selection. |
| `input_height` | `int` | Yes | Input image height (used to derive per-scale stride). |
| `input_width` | `int` | Yes | Input image width (used to derive per-scale stride). |

---

## Available Passes

### `yolo_postprocess`

| Field | Value |
|-------|-------|
| **Target models** | YOLOv8, YOLOv9, YOLOv11, YOLOv12, YOLOv13 |
| **Head structure** | 64-channel bbox (DFL decoding) + `C`-channel classification, optional 32-channel mask coefficient |
| **Supported tasks** | Detection, Instance Segmentation |
| **Output (det)** | `[N, 4 + C, K]` — bbox (xywh) + class scores |
| **Output (seg)** | `[N, 4 + C + M, K]` + `[N, M, H, W]` — det output + mask prototype |

### `yolo26_postprocess`

| Field | Value |
|-------|-------|
| **Target models** | YOLOv10, YOLO26 (models with `one2one` decoupled head) |
| **Head structure** | 64-channel bbox (DFL decoding) + `C`-channel classification (`one2one_cv2` / `one2one_cv3`), no mask coefficient |
| **Supported tasks** | Detection |
| **Output** | `[N, K, 6]` — bbox (xyxy) + score + class_id *(note: K is the second axis, unlike `yolo_postprocess` where channels are the second axis)* |

---

## Identifying Conv Head Tensor Names

The `layers` field expects the **output tensor name** of each Conv head (one per detection scale). You can locate these names with [Netron](https://netron.app) or programmatically:

```python
import onnx
from onnx import shape_inference

model = onnx.load("model.onnx")
model = shape_inference.infer_shapes(model)

# Set this to your model's classification class count.
# Common defaults: 80 (COCO), 1 (single-class), 20 (VOC), etc.
num_classes = 80

for node in model.graph.node:
    if node.op_type == "Conv":
        out = node.output[0]
        for vi in model.graph.value_info:
            if vi.name == out:
                dims = [d.dim_value for d in vi.type.tensor_type.shape.dim]
                # 64ch = bbox (DFL), 4ch = bbox (direct),
                # num_classes-ch = cls, 32ch = mask coefficient
                if len(dims) == 4 and dims[1] in {4, 32, 64, num_classes}:
                    print(f"{node.name} -> {out}: {dims}")
```

---

## Examples

### YOLOv8n Detection (ultralytics export)

```python
import onnx
import dx_com

model = onnx.load("yolov8n.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_postprocess": {
        "layers": [
            {
                "bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0",
            },
            {
                "bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0",
            },
            {
                "bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0",
            },
        ],
        "num_classes": 80,
        "topk": 300,
        "input_height": 640,
        "input_width": 640,
    },
})
# Output: [1, 84, 300]  (4 bbox_xywh + 80 cls scores, K = 300)
```

### YOLOv8n Instance Segmentation (ultralytics export)

```python
import onnx
import dx_com

model = onnx.load("yolov8n-seg.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_postprocess": {
        "layers": [
            {
                "bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0",
                "mask_coeff": "/model.22/cv4.0/cv4.0.2/Conv_output_0",
            },
            {
                "bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0",
                "mask_coeff": "/model.22/cv4.1/cv4.1.2/Conv_output_0",
            },
            {
                "bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0",
                "mask_coeff": "/model.22/cv4.2/cv4.2.2/Conv_output_0",
            },
        ],
        "num_classes": 80,
        "topk": 300,
        "input_height": 640,
        "input_width": 640,
    },
})
# Output 1: [1, 116, 300]  (4 bbox + 80 cls + 32 mask_coeff, K = 300)
# Output 2: [1, 32, 160, 160]  (mask prototype, unchanged)

dx_com.compile(
    model=optimized,
    config="yolov8n-seg.json",
    output_dir="./yolov8n_seg_optimized",
)
```

### YOLO26n Detection (ultralytics export)

```python
import onnx
import dx_com

model = onnx.load("yolo26n.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo26_postprocess": {
        "layers": [
            {
                "bbox": "/model.23/one2one_cv2.0/one2one_cv2.0.2/Conv_output_0",
                "cls_conf": "/model.23/one2one_cv3.0/one2one_cv3.0.2/Conv_output_0",
            },
            {
                "bbox": "/model.23/one2one_cv2.1/one2one_cv2.1.2/Conv_output_0",
                "cls_conf": "/model.23/one2one_cv3.1/one2one_cv3.1.2/Conv_output_0",
            },
            {
                "bbox": "/model.23/one2one_cv2.2/one2one_cv2.2.2/Conv_output_0",
                "cls_conf": "/model.23/one2one_cv3.2/one2one_cv3.2.2/Conv_output_0",
            },
        ],
        "num_classes": 80,
        "topk": 300,
        "input_height": 640,
        "input_width": 640,
    },
})
# Output: [1, 300, 6]  (bbox_xyxy + score + class_id, K = 300)
```

---

## Performance Reference (DeepX DX-M1, ARM Cortex-A53)

| Model | Before (FPS) | After (FPS) | Speed-up |
|-------|---:|---:|---:|
| YOLOv8n det | 61 | 348 | **5.7×** |
| YOLOv8n seg | 59 | 187 | **3.2×** |
| YOLO26n | 176 | 315 | **1.8×** |

End-to-end throughput improves significantly because CPU post-processing is no longer the bottleneck on CPU-constrained hosts.

---

## Migration from PPU Type 2

If you previously used `ppu.type = 2` in the JSON configuration file, switch to `dx_com.pre_optimize()`.

**Previous (deprecated):**

```json
{
  "ppu": {
    "type": 2,
    "topk": 512,
    "num_classes": 80,
    "layer": [
      {"bbox": "bbox_head_p3", "cls_conf": "cls_head_p3"},
      {"bbox": "bbox_head_p4", "cls_conf": "cls_head_p4"},
      {"bbox": "bbox_head_p5", "cls_conf": "cls_head_p5"}
    ]
  }
}
```

**New (`pre_optimize` API):**

```python
import onnx
import dx_com

model = onnx.load("model.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_postprocess": {
        "layers": [
            {"bbox": "bbox_head_p3", "cls_conf": "cls_head_p3"},
            {"bbox": "bbox_head_p4", "cls_conf": "cls_head_p4"},
            {"bbox": "bbox_head_p5", "cls_conf": "cls_head_p5"},
        ],
        "num_classes": 80,
        "topk": 512,
        "input_height": 640,
        "input_width": 640,
    },
})
dx_com.compile(model=optimized, config="config.json", output_dir="./output")
```

**Differences:**

| | PPU Type 2 (previous) | `pre_optimize` (current) |
|--|--|--|
| Configuration location | JSON config file | Python API |
| Segmentation support | ❌ | ✅ |
| YOLOv10 / YOLO26 support | ❌ | ✅ (`yolo26_postprocess`) |
| Required parameters | (none beyond JSON fields) | `input_height`, `input_width` (per-scale stride derivation) |

---
