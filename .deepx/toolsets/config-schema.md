# JSON Config Schema Reference

> Complete config.json schema for DX-COM v2.5.0 compilation.

<!-- VERIFIED against source/docs/02_05_JSON_File_Configuration.md, 02_06_Execution_of_DX-COM.md and 02_09_Pre_Optimize_API.md (v2.5.0) -->

## Parameter Quick Reference

| Key | Required | Description |
|---|---|---|
| `inputs` | Yes | Model input name and shape: `{"name": [1, C, H, W]}` |
| `calibration_method` | No (default `"ema"`) | `"ema"`, `"minmax"`, or `"iqr"` — set it explicitly |
| `calibration_num` | No (default `100`) | Number of calibration samples — set it explicitly |
| `default_loader` | Yes | Dataset location, file types, and preprocessing chain |
| `enhanced_scheme` | No | Manual Q-PRO (DXQ-P0~P5) — opt-in |
| `qmaster` | No | QAT (Q-Master) hyperparameters — its presence enables QAT; opt-in, mutually exclusive with `enhanced_scheme`/`use_q_pro` |
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
      {"div": {"x": 255}},
      {"convertColor": {"form": "BGR2RGB"}},
      {"transpose": {"axis": [2, 0, 1]}},
      {"expandDim": {"axis": 0}}
    ]
  }
}
```

This is an Ultralytics YOLO-style NCHW input (`[1, 3, H, W]`): the chain scales the
BGR/HWC/uint8 image to `[0, 1]`, converts it to RGB, and transposes it to CHW. Adapt the
color and scale steps to the model (see preprocessings below); for an NHWC input, drop
`transpose` but keep `expandDim` (see the R24 note).

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
      {"div": {"x": 255}},
      {"convertColor": {"form": "BGR2RGB"}},
      {"transpose": {"axis": [2, 0, 1]}},
      {"expandDim": {"axis": 0}}
    ]
  },
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

Reference only: `enhanced_scheme` and `ppu` are opt-in — omit them
unless the user asks. Not shown: `qmaster` (opt-in QAT; mutually exclusive with
`enhanced_scheme`/`use_q_pro`) and `pre_optimize` (mutually exclusive with `ppu`) — see
their sections below.

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

### calibration_method (optional, default `ema`)

Lowercase only (`"EMA"` is rejected).

| Value | Description |
|---|---|
| `"ema"` | Exponential Moving Average — default, recommended for most models |
| `"minmax"` | Min/Max range — use when EMA produces poor accuracy |
| `"iqr"` | Interquartile Range (25th–75th percentile) — more robust to outliers than `minmax`; useful when calibration data contains extreme values |

### calibration_num (optional, default `100`)

Number of calibration samples (the manual also calls them calibration steps). Default: `100`.
A positive integer; if the dataset has fewer images, all of them are used without a warning.
A higher number may estimate activation ranges better but increases compile time.
The user manual recommends trying several values (e.g., 1, 5, 10, 100, 1000) and keeping
the one that yields the best accuracy for the model.

### default_loader (required unless using Python API dataloader)

> ⚠️ **NCHW models — `transpose` before the final `expandDim` (R24)**: `default_loader`
> reads images as **HWC** (`cv2.imread`: BGR, uint8) and never transposes them. End
> `preprocessings` with:
>
> | Model input (`inputs`) | Last steps of `preprocessings` |
> |---|---|
> | NCHW `[1, C, H, W]` — e.g. all PyTorch / Ultralytics YOLO exports | `{"transpose": {"axis": [2, 0, 1]}}`, then `{"expandDim": {"axis": 0}}` |
> | NHWC `[1, H, W, C]` | `{"expandDim": {"axis": 0}}` |
>
> Always keep the final `expandDim`, as the manual's examples do: an NHWC model whose
> graph starts with `Transpose(perm=[0,3,1,2])` (e.g. tf2onnx exports) fails without it
> with `Unknown error occurred during compilation. Please contact DEEPX.` (`--verbose`
> shows `ValueError: axes don't match array`). Without the transpose, calibration of an
> NCHW model fails before compilation:
>
> ```
> DataLoaderError: Invalid JSON Configuration for input 'images': The config specifies
> (1, 640, 640, 3), but model requires (1, 3, 640, 640). Please check the preprocessing configuration.
> ```
>
> With `default_loader`, check `compiler.log` before writing host-side preprocessing: the
> `Added nodes` line (manual `02_05`, "Automatic Preprocessing Optimization") and the
> INPUT PREPROCESSING GUIDANCE block list the steps to skip at inference (e.g.
> `Fused ops: Transpose(HWC→CHW) → Div(x=255)`) and the `NPU input` format.
>
> Use a Python `dataloader=` instead only when the JSON ops cannot express the input:
> multi-input models, non-image data, or custom preprocessing (see "Custom DataLoader" in
> `dxcom-api.md`). Then pass no `config=` at all — `config` and `dataloader` are mutually
> exclusive. If the Dataset keeps torchvision transforms in a `transform` attribute (as the
> `dxcom-api.md` example does), DX-COM may extract and fuse them (e.g.
> `Fused ops: Transpose(HWC→CHW) → Div(x=255)`); preprocessing done by hand in
> `__getitem__` gives `Fused ops: (none)`. Either way, follow the INPUT PREPROCESSING
> GUIDANCE block for the inference input.

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
Required array of file extensions to include (without dot), matched case-sensitively — list
`"JPG"` too when files use uppercase extensions. Subfolders are searched:
```json
["jpeg", "png", "jpg", "bmp"]
```

#### preprocessings
Array of preprocessing operations applied in order (one operation key per item):

| Operation | Example | Notes |
|---|---|---|
| `convertColor` | `{"convertColor": {"form": "BGR2RGB"}}` | Case-sensitive; never fused onto the NPU; `*2GRAY` outputs `(H, W, 1)`. `form`: `RGB2BGR`, `BGR2RGB`, `RGB2GRAY`, `BGR2GRAY`, `RGB2YCrCb`, `BGR2YCrCb`, `RGB2YUV`, `BGR2YUV`, `RGB2HSV`, `BGR2HSV`, `RGB2LAB`, `BGR2LAB` |
| `resize` | `{"resize": {"width": 640, "height": 640}}` | Optional `mode` + `interpolation`: `default` (OpenCV: `LINEAR`, `NEAREST`, `CUBIC`, `AREA`, `LANCZOS4`) or `torchvision` (PIL: `BILINEAR`, `NEAREST`, `BICUBIC`, `LANCZOS`) — uppercase names from the same `mode` only. `size` may replace `width`/`height` |
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
manual's YOLO examples use `div` 255. For NCHW inputs, finish the chain with `transpose`
(HWC → CHW) — see the R24 note above.

> **Preprocessing may move onto the NPU**: the compiler may integrate some preprocessing
> operations (e.g. `normalize`, `subtract`, `div`) into the NPU graph. Whether it happens
> depends on the input data type and the model architecture, so it is not guaranteed. Check
> compiler.log for `[INFO] - Added nodes:` — every operation listed there is handled by the
> NPU and MUST be removed from host-side runtime preprocessing; otherwise it is applied twice
> (wrong input values, degraded results).

### quantization_device (deprecated)

Deprecated in v2.5.0 and ignored with a `UserWarning` — never generate it. GPU/CPU is
selected with the CLI `--use_gpu {True,False}` flag or the Python `use_gpu` argument
(default `True`: GPU when available, otherwise CPU), and a specific GPU with
`CUDA_VISIBLE_DEVICES`. GPU quantization requires an NVIDIA GPU with CUDA and a
CUDA-enabled PyTorch (`torch.cuda.is_available()` is `True`).

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
- P1–P5 are compute-heavy; GPU quantization (the default when a GPU is available) can cut
  compile time by 2–5x versus CPU.
- Accuracy improvement is **not guaranteed** and varies by model and dataset.
- Mutually exclusive with automatic Q-PRO (`--use_q_pro` / `use_q_pro=True`), which lets
  DX-COM choose the DXQ combination.
- Not supported for multi-input models.

### qmaster (optional — opt-in QAT)

Quantization-Aware Training (Q-Master). Adding this block switches the compile from PTQ to QAT
with the same `dxcom` command. Requires a CUDA GPU. All keys are optional
(defaults: `batch_size=1`, `train_limit=500`, `val_limit=50`, `epochs=30`, `lr=1e-5`).
Mutually exclusive with `enhanced_scheme`/`use_q_pro`. `default_loader.preprocessings` is shared
with calibration — do not redefine it here. Full reference: `.deepx/toolsets/qat.md`.

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
- RTMDet (`rtmdet_postprocess`, detection only) uses `cls_layers`, `reg_layers`,
  `use_exp`, `nms_boxes_tensor`, `nms_scores_tensor`, `nms_score_tensor`, and optional
  `num_classes` / `topk` instead of `task` + `layers`.
- Head names are Conv output tensors **before Sigmoid** (logits). Do not hand-write
  them: once the user opts in, run `.deepx/scripts/pre_optimize_find_heads.py model.onnx
  --verify` (skill `/dx-agent-compiler-pre-optimize`). dx_com silently ignores misspelled
  keys, so only `--verify` catches a wrong block.
- Full RTMDet example, seg/pose examples, and migration from PPU type 2:
  `source/docs/02_09_Pre_Optimize_API.md`.

## Auto-Inference Rules for Agents

Agents should auto-generate config.json when possible using these rules:

1. **Input name**: `onnx_model.graph.input[0].name`
2. **Input shape**: Extract from ONNX input tensor type
3. **Resize dims**: `width = shape[3]`, `height = shape[2]`
4. **Normalize params**: Infer from model family name. `default_loader` reads BGR, HWC,
   uint8 images (see `default_loader` above), so for RGB models scaled to `[0, 1]` put `div`
   255 and `convertColor` BGR2RGB before `normalize`; end `preprocessings` with
   `{"transpose": {"axis": [2, 0, 1]}}` (NCHW `inputs` only) and `{"expandDim": {"axis": 0}}` (R24)
5. **PPU type** (only after the user opted in to PPU): Infer from model name (the `layer` names still need rule 9):
   - Contains "yolov3", "yolov4", "yolov5", "yolov7" → type 0
   - Contains "yolox", "yolov8", "yolov9", "yolov10", "yolov11", "yolov12" → type 1
   - Never generate type 2 (deprecated)
6. **num_classes**: Default 80 (COCO), ask user if custom
7. **calibration_method**: Default "ema" unless user specifies otherwise ("minmax" and "iqr" are the alternatives)
8. **calibration_num**: Default 100 unless user specifies otherwise
9. **PPU layer names**: CANNOT be auto-inferred — user must inspect ONNX graph in Netron to find correct Conv/output node names
10. **enhanced_scheme / pre_optimize**: Never add automatically — only on explicit user request.
    Once `pre_optimize` is requested for YOLOv8+ / YOLO26 / RTMDet, generate the block with
    `python .deepx/scripts/pre_optimize_find_heads.py model.onnx --verify`
    (`--config config.json` merges it and removes `ppu`). See `/dx-agent-compiler-pre-optimize`.
