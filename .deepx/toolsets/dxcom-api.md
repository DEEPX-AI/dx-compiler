# DX-COM Python API Reference

> Complete reference for the `dx_com.compile()` Python API (DX-COM v2.5.0).

<!-- VERIFIED against source/docs/02_02_Installation_of_DX-COM.md, 02_06_Execution_of_DX-COM.md, 02_07_Quantization_Tuning_Workflow.md and 02_09_Pre_Optimize_API.md (v2.5.0) -->

## Installation

dx-com is published on **PyPI** (since v2.4.0). Requirements: Python 3.8–3.14 on
x86_64 Linux with glibc ≥ 2.31 (wheels are tagged `manylinux_2_31_x86_64`).

System libraries (DX-COM raises `RequiredLibraryError` without them):
```bash
sudo apt-get install -y --no-install-recommends libgl1-mesa-glx libglib2.0-0 make  # Debian / Ubuntu
sudo dnf install -y mesa-libGL glib2 make  # Fedora; on RHEL / CentOS 9–10 enable the CRB repository first
```

Installation methods:
```bash
# 1. Already installed by the dx-compiler installer? Activate its venv:
source dx-compiler/venv-dx-compiler-local/bin/activate   # host mode (container mode: venv-dx-compiler)

# 2. Install from PyPI into an active venv:
pip install dx-com          # or: uv pip install dx-com

# 3. Run the compiler installer (creates/updates the venv; uses uv when available):
bash dx-compiler/install.sh --target=dx_com

# 4. Install a downloaded wheel matching your Python version:
pip install dx_com-<VERSION>-<PYTAG>-<ABITAG>-manylinux_2_31_x86_64.whl
```

Verify the installation:
```bash
dxcom --version
python3 -c "import dx_com; print(dx_com.__version__)"
```

> **Ultralytics `format=deepx` path**: Ultralytics installs `dx_com` itself (version
> pinned by the installed `ultralytics` release) — do not install it manually for that
> path. See `ultralytics-deepx-export.md`.

## Import

```python
import dx_com
from dx_com import PPUConfig, PPUTypes  # optional PPU config objects
from dx_com import QMasterConfig         # only for QAT (Q-Master); see qat.md
```

> **Note**: There is NO `dx_com.DataLoader` class. For custom dataloaders, use
> the standard `torch.utils.data.Dataset` and `torch.utils.data.DataLoader`.
> The legacy `CustomLoader` approach is deprecated.

## dx_com.compile()

### Full Signature

```python
def compile(
    model: Union[str, onnx.ModelProto],
    output_dir: str,
    config: Optional[str] = None,            # mutually exclusive with dataloader
    dataloader: Optional[DataLoader] = None,  # torch.utils.data.DataLoader; mutually exclusive with config
    calibration_method: str = "ema",
    calibration_num: int = 100,
    use_gpu: bool = True,                     # v2.5.0
    opt_level: int = 1,
    aggressive_partitioning: bool = False,
    input_nodes: Optional[List[str]] = None,
    output_nodes: Optional[List[str]] = None,
    use_q_pro: bool = False,
    enhanced_scheme: Optional[Dict] = None,
    ppu_config: Optional[PPUConfig] = None,
    qmaster: Optional[QMasterConfig] = None,  # opt-in QAT (Q-Master), v2.5.0
    gen_log: bool = False,
    float64_calibration: bool = False,
    export_html: bool = False,
    verbose: bool = False,                    # v2.5.0
    **kwargs,
) -> None
```

> **Changed in v2.5.0**: Call `dx_com.compile()` with **keyword arguments**.

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `model` | `str` or `ModelProto` | required | Path to ONNX file or loaded ONNX model (not required with `checkpoint`) |
| `output_dir` | `str` | required | Directory for output .dxnn and logs |
| `config` | `str` | `None` | Path to config.json (mutually exclusive with `dataloader`) |
| `dataloader` | `DataLoader` | `None` | PyTorch `torch.utils.data.DataLoader` (mutually exclusive with `config`). `batch_size` must be 1. Required for multi-input models |
| `calibration_method` | `str` | `"ema"` | `"ema"`, `"minmax"`, or `"iqr"` |
| `calibration_num` | `int` | `100` | Number of calibration samples |
| `quantization_device` | — | — | **Deprecated in v2.5.0 — ignored** with a `UserWarning`. Do not pass it; use `use_gpu` and `CUDA_VISIBLE_DEVICES` |
| `use_gpu` | `bool` | `True` | **(v2.5.0)** `True`=GPU when available (otherwise CPU), `False`=force CPU. Select a specific GPU with `CUDA_VISIBLE_DEVICES`. Pass only `True`/`False` — `None` or a string makes `compile()` fall back to its legacy path, which skips a JSON `pre_optimize` block and ignores `verbose` |
| `opt_level` | `int` | `1` | Optimization level: 0 (minimal) or 1 (full) |
| `aggressive_partitioning` | `bool` | `False` | **(Experimental)** Maximize NPU operations |
| `input_nodes` | `List[str]` | `None` | Partial compilation: input node names (ONNX operator node names) |
| `output_nodes` | `List[str]` | `None` | Partial compilation: output node names (ONNX operator node names) |
| `use_q_pro` | `bool` | `False` | Automatic Q-PRO pipeline (ONNX compile path; also allowed with `checkpoint`). Mutually exclusive with `enhanced_scheme` |
| `enhanced_scheme` | `Dict` | `None` | Manual Q-PRO scheme (`"DXQ-P0"`–`"DXQ-P5"`). Not supported for multi-input models. Also usable with `checkpoint` (the CLI flag `--enhanced_scheme` is resume-only; normal CLI compiles set it in the JSON) |
| `ppu_config` | `PPUConfig` | `None` | PPU configuration object — Python equivalent of the JSON `ppu` section. `None` = PPU disabled |
| `qmaster` | `QMasterConfig` | `None` | Opt-in Quantization-Aware Training (Q-Master, v2.5.0). Use ONLY when the user explicitly requests QAT. Mutually exclusive with `use_q_pro`/`enhanced_scheme`. See `qat.md` |
| `gen_log` | `bool` | `False` | Generate compiler.log |
| `float64_calibration` | `bool` | `False` | float64 calibration for cross-CPU determinism |
| `export_html` | `bool` | `False` | Generate the Compilation Summary Report `<model_name>_summary.html` in `output_dir` |
| `verbose` | `bool` | `False` | **(v2.5.0)** Expand masked error messages |

**Advanced parameters** — documented outside the signature above; confirm with
`help(dx_com.compile)`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `quant_diagnosis` | `bool` | `False` | Write `quant_diagnosis/diagnosis_report.html` and a resume checkpoint `quant_diagnosis/<model>.qxnn` under `output_dir` |
| `checkpoint` | `str` | `None` | `.qxnn` path — QXNN resume mode (re-quantize without recompiling). `model`/`config` are not required — the manual's resume example passes neither, and on the CLI `--checkpoint` and `-m` are mutually exclusive. Any other extension raises `ValueError` |
| `recalibration_method` | `str` | — | **(Resume-only)** Observer override: `"minmax"`, `"ema"`, or `"iqr"` |
| `dataset_path` | `str` | — | **(Resume-only)** Override the calibration dataset path embedded in the checkpoint |

Resume-only parameters raise an error without `checkpoint`. On resume the calibration
DataLoader is rebuilt from the config embedded in the `.qxnn` (default loader only) —
resuming a compile that used `dataloader=` is not documented. The result is written as
`{checkpoint_stem}.dxnn` (override with `output_name`).

### Mutual Exclusivity

`config` and `dataloader` are **mutually exclusive**. Provide exactly one:
- `config`: Path to config.json with `default_loader` section
- `dataloader`: Standard `torch.utils.data.DataLoader` instance with `batch_size=1`

If both are provided, DX-COM raises `ValueError`.
If neither is provided, DX-COM raises `ValueError`.

When compiling with a `dataloader`, no config file is passed, so pass everything else as
keyword arguments — e.g. PPU settings via `ppu_config=PPUConfig(...)`.

Other pairs that must not be combined:

| Pair | Rule |
|---|---|
| `use_q_pro` ↔ `enhanced_scheme` | Automatic vs manual Q-PRO — set only one |
| `qmaster` ↔ `use_q_pro`/`enhanced_scheme` | QAT and Q-PRO re-quantization are mutually exclusive (`EnhancementSchemeError`) |
| `checkpoint` ↔ `model` | Resume mode re-quantizes an existing `.qxnn` |
| JSON `ppu` ↔ JSON `pre_optimize` | Both rewrite detection post-processing — see `config-schema.md` |

## Code Examples

### Basic Compilation with Config

```python
import dx_com

dx_com.compile(
    model="yolov8n.onnx",
    output_dir="output/",
    config="config.json",
)
```

### Basic Compilation with All Options

```python
import dx_com

dx_com.compile(
    model="yolov8n.onnx",
    output_dir="output/",
    config="config.json",
    calibration_method="ema",
    calibration_num=200,
    opt_level=1,
    gen_log=True,
    export_html=True,
)
```

### Custom DataLoader

<!-- VERIFIED: Uses torch.utils.data.Dataset + DataLoader, NOT dx_com.DataLoader -->

```python
import dx_com
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import os

class MyDataset(Dataset):
    def __init__(self, image_dir, input_shape):
        self.image_dir = image_dir
        self.image_files = sorted([
            f for f in os.listdir(image_dir)
            if f.endswith(('.jpg', '.jpeg', '.png'))
        ])
        self.transform = transforms.Compose([
            transforms.Resize((input_shape[2], input_shape[3])),
            transforms.ToTensor(),  # HWC uint8 -> CHW float [0,1]
        ])

    def __len__(self):
        return len(self.image_files)

    def __getitem__(self, idx):
        img = Image.open(
            os.path.join(self.image_dir, self.image_files[idx])
        ).convert("RGB")
        return self.transform(img)

dataset = MyDataset("/data/coco/val2017", (1, 3, 640, 640))
dataloader = DataLoader(dataset, batch_size=1, shuffle=True)

dx_com.compile(
    model="yolov8n.onnx",
    output_dir="output/",
    dataloader=dataloader,
    calibration_method="ema",
    calibration_num=100,
    export_html=True,
)
```

When compiling with a `dataloader`, the JSON `default_loader.preprocessings` block is
not used — all preprocessing (resize, color order, normalization, layout) must happen in
`__getitem__` and must match the inference-time preprocessing. Each item is the model
input shape without the batch dimension (e.g. `[3, 640, 640]`), `float32`. For multi-input
models, returning a `dict[str, torch.Tensor]` keyed by ONNX input name is recommended.

### PPU via `ppu_config`

PPU stays opt-in (see `config-schema.md` → ppu). Python equivalent of the JSON `ppu` section:

```python
import dx_com
from dx_com import PPUConfig, PPUTypes

ppu = (
    PPUConfig()
    .set_type(PPUTypes.YOLO_ANCHORFREE)  # type 1: YOLOX, YOLOv8–v12
    .set_num_classes(80)
    .set_conf_thres(0.25)
)
ppu.add_layer(bbox="Mul_441", cls_conf="Sigmoid_442")  # YOLOv8–v12: the nodes that feed the final output Concat; read the names from your ONNX graph

dx_com.compile(
    model="yolov8n.onnx",
    output_dir="output/",
    dataloader=dataloader,
    ppu_config=ppu,
    export_html=True,
)
```

| `PPUTypes` | Value | Models |
|---|---|---|
| `PPUTypes.YOLO_BASE` | 0 | Anchor-based: YOLOv3/v4/v5/v7 — `add_layer("Conv_245", num_anchors=3)` per head, plus `set_activation("Sigmoid")` |
| `PPUTypes.YOLO_ANCHORFREE` | 1 | Anchor-free: YOLOX, YOLOv8–v12. YOLOX: one `add_layer(bbox=..., obj_conf=..., cls_conf=...)` per detection scale. YOLOv8–v12: a single `add_layer(bbox=..., cls_conf=...)` naming the two nodes that feed the final output `Concat` — `bbox` (decoded boxes, usually a `Mul`, shape `[1, 4, N]`) and `cls_conf` (a `Sigmoid`, shape `[1, num_classes, N]`). These already cover every detection scale, so do not add one entry per scale. Node names are model-specific; read them from the ONNX graph (e.g. Netron), as in `config-schema.md` |
| `PPUTypes.YOLOV8` | 2 | **Deprecated since v2.4.0** — the DFL-based CPU TopK path for YOLOv8/v9/v11/v12. Do not use it in new configs even though the name matches YOLOv8: use `YOLO_ANCHORFREE` (PPU) or its replacement `dx_com.pre_optimize()` |

`compile()` calls `ppu_config.validate()` and raises if required fields are missing.
`set_type()` resets `layer`, so call it before `add_layer()`.

### Post-Processing Optimization via `dx_com.pre_optimize()`

Opt-in only, and mutually exclusive with PPU (see `config-schema.md` → pre_optimize).
Unlike the JSON block (a list of single-key dicts), the Python API takes a **dict**
`{pass_name: config}`; passes run in the given order:

```python
import onnx
import dx_com

model = onnx.load("yolov8n.onnx")  # full model: the network input is used to derive strides
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
        "num_classes": 80,  # required for yolo_dfl_postprocess
        "topk": 300,
    },
})
# Output: [1, 84, 300] (4 bbox xywh + 80 class scores, K = 300)

dx_com.compile(model=optimized, output_dir="output/", dataloader=dataloader)  # or config="config.json"
```

The optimized model still needs calibration input: pass exactly one of `dataloader=` or
`config=` (they stay mutually exclusive).
Signature: `dx_com.pre_optimize(model: onnx.ModelProto, passes: dict[str, dict]) -> onnx.ModelProto`.
Raises `KeyError` (unknown or old pass name, missing required key) and `ValueError`
(unresolvable tensor name in `layers`, or invalid `task`). Pass fields and the other
passes: `config-schema.md` → pre_optimize and `source/docs/02_09_Pre_Optimize_API.md`.

### Partial Compilation

```python
import dx_com

dx_com.compile(
    model="model.onnx",
    output_dir="output/",
    config="config.json",
    input_nodes=["conv1_output"],
    output_nodes=["fc_output"],
)
```

### Enhanced Quantization (DXQ-P3)

```python
import dx_com

dx_com.compile(
    model="resnet50.onnx",
    output_dir="output/",
    config="config.json",
    enhanced_scheme={"DXQ-P3": {"num_samples": 1024}},
    gen_log=True,
)
```

### Automatic Q-PRO

Opt-in only — use when the user asks for higher-accuracy quantization.

```python
import dx_com

dx_com.compile(
    model="model.onnx",
    output_dir="output/",
    config="config.json",
    use_q_pro=True,  # do not combine with enhanced_scheme
)
```

### Quantization Diagnosis and QXNN Resume

```python
import dx_com

# 1. Compile once with diagnosis
dx_com.compile(
    model="large_model.onnx",
    output_dir="output/large_model",
    config="config.json",
    quant_diagnosis=True,
)

# 2. Re-quantize from the checkpoint without recompiling
dx_com.compile(
    checkpoint="output/large_model/quant_diagnosis/large_model.qxnn",
    output_dir="output/large_model_iqr",
    recalibration_method="iqr",  # or: use_q_pro=True
)
```

Full workflow: `source/docs/02_07_Quantization_Tuning_Workflow.md`.

### Loading ONNX Model Directly

```python
import dx_com
import onnx

model = onnx.load("model.onnx")
# Optionally modify the model graph here

dx_com.compile(
    model=model,  # Pass ModelProto directly
    output_dir="output/",
    config="config.json",
)
```

## Return Value

`dx_com.compile()` returns `None`. Output artifacts are written to `output_dir`:
- `<model_name>.dxnn` — Compiled model
- `compiler.log` — Compilation log (only if `gen_log=True`)
- `<model_name>_summary.html` — Compilation Summary Report (only if `export_html=True`)
- `quant_diagnosis/diagnosis_report.html` and `quant_diagnosis/<model>.qxnn` (only if `quant_diagnosis=True`)

## Exceptions

DX-COM error types listed in the user manual (`source/docs/02_06_Execution_of_DX-COM.md`
→ Common Errors and Troubleshooting):

| Error | Typical cause |
|---|---|
| `NotSupportError` | Unsupported feature — e.g. multi-input model with the `dxcom` CLI, dynamic input shape, cubic resize |
| `ConfigFileError` | Invalid or missing JSON config (bad path, malformed JSON) |
| `ConfigInputError` | Config `inputs` name or shape does not match the ONNX model |
| `DatasetPathError` | `dataset_path` does not exist or is not a directory |
| `DataNotFoundError` | No valid input data in `dataset_path` (empty folder, wrong extensions) |
| `NodeNotFoundError` | The ONNX model contains a node unsupported by the compiler |
| `NotsupportedPaddingError` | Unsupported padding (e.g. asymmetric padding in width and height) |
| `OnnxFileNotFound` | ONNX model file not found |
| `RequiredLibraryError` | Missing system library (e.g. `libgl1-mesa-glx`) |
| `OSError`, `UbuntuVersionError`, `LDDVersionError`, `RamSizeError`, `DiskSizeError` | Host environment outside the supported range |

Pass `verbose=True` (CLI: `--verbose`) to expand masked error messages.

<!-- NOTE: The generic Python exceptions below predate the v2.5.0 manual and are NOT documented
     there. Prefer the DX-COM error types above when diagnosing. -->

| Exception | Cause (not in the user manual) |
|---|---|
| `FileNotFoundError` | Model or config path does not exist |
| `ValueError` | Both `config` and `dataloader` provided, or neither |
| `RuntimeError` | Compilation failure (unsupported op, shape mismatch, etc.) |
| `onnx.checker.ValidationError` | Invalid ONNX model |
