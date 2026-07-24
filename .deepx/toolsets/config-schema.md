# JSON Config Schema Reference

> Complete config.json schema for DX-COM v2.2.1 compilation.

## Minimal Config

```json
{
  "inputs": {"images": [1, 3, 640, 640]},
  "calibration_method": "ema",
  "calibration_num": 100,
  "default_loader": {
    "dataset_path": "/path/to/calibration/images",
    "file_extensions": ["jpeg", "png", "jpg"],
    "preprocessings": [
      {"resize": {"width": 640, "height": 640}},
      {"normalize": {"mean": [0.0, 0.0, 0.0], "std": [1.0, 1.0, 1.0]}}
    ]
  }
}
```

## Full Config (All Fields)

```json
{
  "inputs": {"images": [1, 3, 640, 640]},
  "calibration_method": "ema",
  "calibration_num": 100,
  "default_loader": {
    "dataset_path": "/path/to/calibration/images",
    "file_extensions": ["jpeg", "png", "jpg"],
    "preprocessings": [
      {"resize": {"width": 640, "height": 640}},
      {"normalize": {"mean": [0.0, 0.0, 0.0], "std": [1.0, 1.0, 1.0]}}
    ]
  },
  "quantization_device": "cuda:0",
  "enhanced_scheme": {"DXQ-P3": {"num_samples": 1024}},
  "ppu": {
    "type": 1,
    "conf_thres": 0.25,
    "num_classes": 80,
    "layer": [
      {"bbox": "Mul_441", "cls_conf": "Sigmoid_442"}
    ]
  }
}
```

## Field Reference

### inputs (required)

```json
{"input_name": [batch, channels, height, width]}
```

| Rule | Details |
|---|---|
| Key name | Must **exactly** match ONNX model input node name |
| Shape | Must **exactly** match ONNX model input shape |
| Batch | Must be `1` — no other value supported |
| Dimensions | All must be positive integers (no -1, no 0) |

**How to find the correct input name**:
```python
import onnx
model = onnx.load("model.onnx")
for inp in model.graph.input:
    name = inp.name
    shape = [d.dim_value for d in inp.type.tensor_type.shape.dim]
    print(f'"{name}": {shape}')
```

### calibration_method (required)

| Value | Description |
|---|---|
| `"ema"` | Exponential Moving Average — default, recommended for most models |
| `"minmax"` | Min/Max range — use when EMA produces poor accuracy |

### calibration_num (required)

Number of calibration samples. Default: `100`.
- Minimum recommended: 50
- Optimal range: 100-500
- Diminishing returns after ~500

### default_loader (required unless using Python API dataloader)

> ⚠️ **WARNING — NCHW Models (R24)**: `default_loader` produces **HWC (height, width,
> channels)** tensors. All NCHW models (e.g., **all YOLO variants** — yolo26n, yolov8,
> yolov9, yolov10, yolov11, yolov12, yolov3, yolov5, yolov7, YOLOX) will **always**
> fail calibration with a shape mismatch error when using `default_loader`.
>
> **NEVER use `default_loader` for NCHW models.** Use a PyTorch DataLoader with
> `transforms.ToTensor()` (produces NCHW float32) instead. See the "Custom DataLoader"
> example in `dxcom-api.md`.
>
> Symptom: `DataLoaderError: shape mismatch` or `expected [1,3,H,W] got [1,H,W,3]`
> Fix: Replace `default_loader` in config.json with a Python DataLoader using
> `transforms.ToTensor()`. Remove the `default_loader` key entirely from config.json
> when calling `dx_com.compile(..., dataloader=custom_loader)`.
>
> `default_loader` is only appropriate for models expecting HWC input (rare).

#### dataset_path
Absolute or relative path to directory containing calibration images.

> **⚠️ Path resolution**: `dataset_path` is resolved relative to the **working
> directory where `dx_com.compile()` is called** (typically the repository root
> or the session directory), NOT relative to the config file's location.
> In autopilot sessions where `dx_com.compile()` may be called from the repo root,
> always prefer **absolute paths** to avoid `DataNotFoundError`:
> ```python
> import os, json
> config["default_loader"]["dataset_path"] = os.path.abspath("dx_com/calibration_dataset")
> ```
> If using a relative path, ensure it is relative to the directory from which
> `dx_com.compile()` will be invoked (e.g., `./calibration_dataset` when running
> from `${WORK_DIR}/`).

#### file_extensions
Array of file extensions to include (without dot):
```json
["jpeg", "png", "jpg", "bmp"]
```

#### preprocessings
Array of preprocessing operations applied in order:

**resize**:
```json
{"resize": {"width": 640, "height": 640}}
```
Width and height should match the spatial dimensions of `inputs` shape.

**normalize**:
```json
{"normalize": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}}
```

Common normalization values:

| Model Family | Mean | Std |
|---|---|---|
| YOLO (all versions) | `[0.0, 0.0, 0.0]` | `[1.0, 1.0, 1.0]` |
| ImageNet (ResNet, etc.) | `[0.485, 0.456, 0.406]` | `[0.229, 0.224, 0.225]` |
| Raw (0-255 → 0-1) | `[0.0, 0.0, 0.0]` | `[255.0, 255.0, 255.0]` |

### quantization_device (optional — wheel package only)

Device for quantization computation. Auto-detects GPU by default:
- Not specified or `null` — Auto-detect (GPU if available, otherwise CPU)
- `"cpu"` — Force CPU quantization
- `"cuda"` — Use default CUDA GPU
- `"cuda:0"` — Use first GPU
- `"cuda:1"` — Use second GPU

### enhanced_scheme (optional)

Advanced quantization methods:
```json
{"DXQ-P3": {"num_samples": 1024}}
```

DXQ-P3 provides higher quantization accuracy at the cost of 3-5x longer
calibration time. `num_samples` controls the number of samples used for
the enhanced calibration pass.

### ppu (optional — detection models only)

Post-Processing Unit configuration for YOLO detection models. The PPU performs
hardware-accelerated confidence filtering and class prediction (Argmax) on the NPU.
**NMS is NOT supported by the PPU** — it must run on the host CPU.

<!-- VERIFIED against source/docs/02_05_JSON_File_Configuration.md -->

#### Common Fields

| Field | Type | Description |
|---|---|---|
| `type` | `int` | 0=anchor-based, 1=anchor-free |
| `conf_thres` | `float` | Confidence threshold (fixed at compile time) |
| `num_classes` | `int` | Number of detection classes |
| `layer` | `dict` or `list` | Layer configuration mapping Conv/output node names (see below) |
| `activation` | `str` | Activation function (Type 0 only, e.g., `"Sigmoid"`) |

> **Note**: `iou_thres` and `max_det` do NOT exist in the PPU schema. NMS parameters
> are handled at runtime on the host CPU, not at compile time.

#### PPU Type 0 — Anchor-Based (YOLOv3/v4/v5/v7)

```json
{
  "ppu": {
    "type": 0,
    "conf_thres": 0.25,
    "activation": "Sigmoid",
    "num_classes": 80,
    "layer": {
      "Conv_245": {"num_anchors": 3},
      "Conv_294": {"num_anchors": 3},
      "Conv_343": {"num_anchors": 3}
    }
  }
}
```

The `layer` field is a **dict** mapping detection head Conv node names (found via
Netron) to anchor configurations. Each Conv outputs a feature map with shape
`[1, num_anchors*(5+num_classes), H, W]`.

#### PPU Type 1 — Anchor-Free

**YOLOX** — uses `bbox`, `obj_conf`, and `cls_conf` per scale:
```json
{
  "ppu": {
    "type": 1,
    "conf_thres": 0.25,
    "num_classes": 80,
    "layer": [
      {"bbox": "output_bbox_1", "obj_conf": "output_obj_1", "cls_conf": "output_cls_1"},
      {"bbox": "output_bbox_2", "obj_conf": "output_obj_2", "cls_conf": "output_cls_2"},
      {"bbox": "output_bbox_3", "obj_conf": "output_obj_3", "cls_conf": "output_cls_3"}
    ]
  }
}
```

**YOLOv8/v9/v10/v11/v12** — uses `bbox` and `cls_conf` only (one entry):
```json
{
  "ppu": {
    "type": 1,
    "conf_thres": 0.25,
    "num_classes": 80,
    "layer": [
      {"bbox": "Mul_441", "cls_conf": "Sigmoid_442"}
    ]
  }
}
```

The `layer` field is a **list** of dicts. Node names must be identified from the ONNX
graph using Netron. Use ONNX operator node names, not tensor/edge names.

## Auto-Inference Rules for Agents

Agents should auto-generate config.json when possible using these rules:

1. **Input name**: `onnx_model.graph.input[0].name`
2. **Input shape**: Extract from ONNX input tensor type
3. **Resize dims**: `width = shape[3]`, `height = shape[2]`
4. **Normalize params**: Infer from model family name
5. **PPU type**: Infer from model name:
   - Contains "yolov3", "yolov4", "yolov5", "yolov7" → type 0
   - Contains "yolox", "yolov8", "yolov9", "yolov10", "yolov11", "yolov12" → type 1
6. **num_classes**: Default 80 (COCO), ask user if custom
7. **calibration_method**: Default "ema" unless user specifies otherwise
8. **calibration_num**: Default 100 unless user specifies otherwise
9. **PPU layer names**: CANNOT be auto-inferred — user must inspect ONNX graph in Netron to find correct Conv/output node names
