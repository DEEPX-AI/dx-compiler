# JSON Config Schema Reference

> Complete config.json schema for DX-COM v2.5.0 compilation.

<!-- VERIFIED against source/docs/02_05_JSON_File_Configuration.md, 02_06_Execution_of_DX-COM.md and 02_09_Pre_Optimize_API.md (v2.5.0) -->

## Parameter Quick Reference

| Key | Required | Description |
|---|---|---|
| `inputs` | Yes | Model input name and shape: `{"name": [1, C, H, W]}` |
| `calibration_method` | Yes | `"ema"`, `"minmax"`, or `"iqr"` |
| `calibration_num` | Yes | Number of calibration samples (e.g., 100) |
| `default_loader` | Yes | Dataset location, file types, and preprocessing chain |
| `quantization_device` | No | Device for quantization; GPU auto-selected if available |
| `enhanced_scheme` | No | Manual Q-PRO (DXQ-P0~P5) — opt-in |
| `ppu` | No | YOLO detection post-processing — opt-in. Mutually exclusive with `pre_optimize` |
| `pre_optimize` | No | ONNX-level post-processing optimization for YOLO/RTMDet — opt-in. Mutually exclusive with `ppu` |

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

## Full Config (Reference)

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

Reference only: `quantization_device`, `enhanced_scheme`, and `ppu` are opt-in — omit them
unless the user asks. Not shown: `pre_optimize` (mutually exclusive with `ppu`) — see its
section below.

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
| Count | JSON config / `dxcom` CLI: single input only — multi-input models need the Python API `dataloader` |

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
| `"iqr"` | Interquartile Range (25th–75th percentile) — more robust to outliers than `minmax`; useful when calibration data contains extreme values |

### calibration_num (required)

Number of calibration samples (the manual also calls them calibration steps). Default: `100`.
A higher number may estimate activation ranges better but increases compile time.
The user manual recommends trying several values (e.g., 1, 5, 10, 100, 1000) and keeping
the one that yields the best accuracy for the model.

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
> `transforms.ToTensor()`. When calling `dx_com.compile(..., dataloader=custom_loader)`,
> do not pass `config=` at all — `config` and `dataloader` are mutually exclusive.
>
> `default_loader` is only appropriate for models expecting HWC input (rare).

`default_loader` reads each image with `cv2.imread` (**BGR, HWC, uint8**) and then applies
`preprocessings` in order.

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

| Operation | Example | Notes |
|---|---|---|
| `convertColor` | `{"convertColor": {"form": "BGR2RGB"}}` | `form`: `RGB2BGR`, `BGR2RGB`, `RGB2GRAY`, `BGR2GRAY`, `RGB2YCrCb`, `BGR2YCrCb`, `RGB2YUV`, `BGR2YUV`, `RGB2HSV`, `BGR2HSV`, `RGB2LAB`, `BGR2LAB` |
| `resize` | `{"resize": {"width": 640, "height": 640}}` | Optional `mode` + `interpolation`: `default` (OpenCV: `LINEAR`, `NEAREST`, `CUBIC`, `AREA`, `LANCZOS4`) or `torchvision` (PIL: `BILINEAR`, `NEAREST`, `BICUBIC`, `LANCZOS`). `size` may replace `width`/`height` |
| `centercrop` | `{"centercrop": {"width": 224, "height": 224}}` | Crop the central region |
| `transpose` | `{"transpose": {"axis": [2, 0, 1]}}` | Rearrange tensor dimensions |
| `expandDim` | `{"expandDim": {"axis": 0}}` | Add a dimension at `axis` |
| `normalize` | `{"normalize": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}}` | `(x - mean) / std` |
| `mul`, `add`, `subtract`, `div` | `{"div": {"x": 255}}` | Arithmetic with a scalar `x` (`div` also accepts a per-channel list) |

Less common registry operations (`resize2`, `resize3`, `resize_tv`, `centercrop2`,
`squeeze`, `slice`, `dtype`, `pil_2_cv`) are listed in
`source/docs/02_06_Execution_of_DX-COM.md` (DataLoader mapping table).

`resize` width and height should match the spatial dimensions of `inputs` shape.

Common normalization values:

| Model Family | Mean | Std |
|---|---|---|
| YOLO (all versions) | `[0.0, 0.0, 0.0]` | `[1.0, 1.0, 1.0]` |
| ImageNet (ResNet, etc.) | `[0.485, 0.456, 0.406]` | `[0.229, 0.224, 0.225]` |
| Raw (0-255 → 0-1) | `[0.0, 0.0, 0.0]` | `[255.0, 255.0, 255.0]` |

Operations run in list order. `default_loader` yields BGR uint8 values (0–255), so for RGB
models whose mean/std are in `[0, 1]` scale (e.g. ImageNet), put
`{"convertColor": {"form": "BGR2RGB"}}` and `{"div": {"x": 255}}` **before** `normalize`.
The "Raw" row (`std` 255) and `div` 255 both scale to `[0, 1]` — use one, not both; the
manual's YOLO examples use `div` 255.

> **Preprocessing may move onto the NPU**: the compiler may integrate some preprocessing
> operations (e.g. `normalize`, `subtract`, `div`) into the NPU graph. Whether it happens
> depends on the input data type and the model architecture, so it is not guaranteed. Check
> compiler.log for `[INFO] - Added nodes:` — every operation listed there is handled by the
> NPU and MUST be removed from host-side runtime preprocessing; otherwise it is applied twice
> (wrong input values, degraded results).

### quantization_device (optional)

Device for quantization computation. Auto-detects GPU by default:
- Not specified or `null` — Auto-detect (GPU if available, otherwise CPU)
- `"cpu"` — Force CPU quantization
- `"cuda"` — Use default CUDA GPU
- `"cuda:0"` — Use first GPU
- `"cuda:1"` — Use second GPU

GPU quantization requires an NVIDIA GPU with CUDA and a CUDA-enabled PyTorch
(`torch.cuda.is_available()` is `True`). Since v2.5.0 the CLI `--use_gpu {True,False}`
flag and the Python `use_gpu` argument toggle GPU/CPU without editing the JSON; use only
one mechanism. `quantization_device` is the one to use for an explicit device string, and
it takes precedence.

### enhanced_scheme (optional)

Manual Q-PRO quantization enhancement (DX-COM v2.1.0+). Opt-in only — see
`instructions/compilation-workflow.md` → Q-PRO.

| Scheme | Compilation Speed | Accuracy Improvement | Form |
|---|---|---|---|
| `DXQ-P0` | Very Fast | Low | `{"DXQ-P0": {"alpha": 0.5}}` |
| `DXQ-P1` | Very Slow | Low-Middle | `{"DXQ-P1": true}` |
| `DXQ-P2` | Very Slow | Middle-High | `{"DXQ-P2": {"alpha": 0.1, "beta": 1.0, "cosim_num": 2}}` |
| `DXQ-P3` | Very Slow | High | `{"DXQ-P3": {"num_samples": 1024}}` |
| `DXQ-P4` | Very Slow | High | `{"DXQ-P4": {"num_samples": 1024}}` |
| `DXQ-P5` | Very Slow | High | `{"DXQ-P5": {"num_samples": 1024}}` |

- DXQ-P3 and DXQ-P4 generally give the best accuracy — try them first. `num_samples` is
  optional for P3–P5 (recommended: 1024).
- P1–P5 are compute-heavy; GPU quantization (`quantization_device: "cuda"`) can cut
  compile time by 2–5x versus CPU.
- Accuracy improvement is **not guaranteed** and varies by model and dataset.
- Mutually exclusive with automatic Q-PRO (`--use_q_pro` / `use_q_pro=True`), which lets
  DX-COM choose the DXQ combination.
- Not supported for multi-input models.

### ppu (optional — detection models only)

Post-Processing Unit configuration for YOLO detection models. The PPU performs
hardware-accelerated confidence filtering and class prediction (Argmax) on the NPU.
**NMS is NOT supported by the PPU** — it must run on the host CPU.
`ppu` and `pre_optimize` are **mutually exclusive** in one config.

<!-- VERIFIED against source/docs/02_05_JSON_File_Configuration.md -->

#### Common Fields

| Field | Type | Description |
|---|---|---|
| `type` | `int` | 0=anchor-based, 1=anchor-free, 2=DFL-based CPU TopK (**deprecated since v2.4.0**) |
| `conf_thres` | `float` | Confidence threshold (fixed at compile time; type 0/1) |
| `num_classes` | `int` | Number of detection classes |
| `layer` | `dict` or `list` | Layer configuration mapping Conv/output node names (see below) |
| `activation` | `str` | Activation function (Type 0 only, e.g., `"Sigmoid"`) |
| `topk` | `int` | Candidates kept before decoding (Type 2 only) |

> **Note**: `iou_thres` and `max_det` do NOT exist in the PPU schema. NMS parameters
> are handled at runtime on the host CPU, not at compile time.

> **Python API**: with `dx_com.compile(..., dataloader=...)` no config file is passed, so
> supply PPU settings as `ppu_config=PPUConfig(...)` — see `dxcom-api.md`.

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

#### PPU Type 2 — DFL-Based CPU TopK (Deprecated)

> ⚠️ **Deprecated since v2.4.0** — still compiles but emits a deprecation warning.
> Do NOT generate type 2 for new configs; use `pre_optimize` (below) instead. Type 2
> does not use the PPU hardware: TopK and decoding run on the host CPU.

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

### pre_optimize (optional — ONNX-level post-processing optimization)

A **list** of single-key `{pass_name: config}` dicts, applied in order to the raw ONNX
before compilation (`dx_com.compile()` runs the passes automatically). The Python
equivalent `dx_com.pre_optimize()` takes a **dict** `{pass_name: config}` instead — see
`dxcom-api.md`. It is the recommended replacement for the deprecated PPU type 2 and is
**mutually exclusive with `ppu`**. The JSON block is documented from v2.5.0;
`dx_com.pre_optimize()` exists since v2.4.0 (with the pre-v2.5.0 pass names).

| Pass | Target models | Tasks | Output |
|---|---|---|---|
| `yolo_dfl_postprocess` | YOLOv8 / v9 / v11 / v12 / v13 | `base` · `seg` · `pose` | `[N, 4+C (+mask or +keypoints), K]` |
| `yolo_no_dfl_postprocess` | YOLO26 (NMS-free) | `base` · `seg` · `pose` | `[N, K, 6 (+mask or +keypoints)]` |
| `rtmdet_postprocess` | RTMDet S / M / L / X | detection only (no `task` key) | NMS tensors (original NMS preserved) |

**Breaking changes in v2.5.0**:
- Renamed passes: `yolo_postprocess` → `yolo_dfl_postprocess`, `yolo26_postprocess` → `yolo_no_dfl_postprocess` (old names raise an error)
- YOLO passes require an explicit `task`: `base` (detection), `seg`, or `pose`
- `input_height` / `input_width` were removed — delete them from old configs; the input size is now derived from the model input, and supplying them raises `ValueError`

YOLO pass fields:

| Field | Required | Description |
|---|---|---|
| `task` | Yes | `base`, `seg`, or `pose` |
| `layers` | Yes | One entry per detection scale. `base`: `bbox`, `cls_conf` · `seg`: + `mask_coeff` · `pose`: + `kpt` and `kpt_shape` |
| `num_classes` | `yolo_dfl_postprocess`: Yes · `yolo_no_dfl_postprocess`: No (default `80`) | Number of classes |
| `topk` | No (default `300`) | Candidates kept after TopK selection |

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
        "topk": 300
      }
    }
  ]
}
```

- `layers` takes Conv-head **output tensor names** (e.g. `.../Conv_output_0`), unlike
  `ppu.layer` for types 0/1, which takes operator node names (e.g. `Mul_441`).
- **Opt-in only** (like PPU): the pass changes the model's output tensor layout, so the
  downstream post-processing must match. Do not add it unless the user asks.
- RTMDet fields, seg/pose examples, and migration from PPU type 2:
  `source/docs/02_09_Pre_Optimize_API.md`.

## Auto-Inference Rules for Agents

Agents should auto-generate config.json when possible using these rules:

1. **Input name**: `onnx_model.graph.input[0].name`
2. **Input shape**: Extract from ONNX input tensor type
3. **Resize dims**: `width = shape[3]`, `height = shape[2]`
4. **Normalize params**: Infer from model family name
5. **PPU type** (only after the user opted in to PPU): Infer from model name (the `layer` names still need rule 9):
   - Contains "yolov3", "yolov4", "yolov5", "yolov7" → type 0
   - Contains "yolox", "yolov8", "yolov9", "yolov10", "yolov11", "yolov12" → type 1
   - Never generate type 2 (deprecated)
6. **num_classes**: Default 80 (COCO), ask user if custom
7. **calibration_method**: Default "ema" unless user specifies otherwise ("minmax" and "iqr" are the alternatives)
8. **calibration_num**: Default 100 unless user specifies otherwise
9. **PPU layer names**: CANNOT be auto-inferred — user must inspect ONNX graph in Netron to find correct Conv/output node names
10. **enhanced_scheme / pre_optimize**: Never add automatically — only on explicit user request
