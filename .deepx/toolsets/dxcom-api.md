# DX-COM Python API Reference

> Complete reference for the `dx_com.compile()` Python API (DX-COM v2.2.1).

## Installation

dx-com is a **private package** — it is NOT available on public PyPI.

Installation methods (in order of preference):
```bash
# 1. Activate the pre-installed compiler venv (RECOMMENDED):
source dx-compiler/venv-dx-compiler-local/bin/activate

# 2. Run the compiler installer (creates/updates the venv):
bash dx-compiler/install.sh

# 3. Install from local wheel (if available in the venv):
pip install dx-compiler/dist/dx_com-*.whl
```

> **NEVER use `pip install dx-com`** — this will fail with "No matching distribution found"
> because dx-com is not published to PyPI. Always use one of the methods above.

## Import

```python
import dx_com
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
    quantization_device: Optional[str] = None,
    opt_level: int = 1,
    aggressive_partitioning: bool = False,
    input_nodes: Optional[List[str]] = None,
    output_nodes: Optional[List[str]] = None,
    enhanced_scheme: Optional[Dict] = None,
    gen_log: bool = False,
) -> None
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `model` | `str` or `ModelProto` | required | Path to ONNX file or loaded ONNX model |
| `output_dir` | `str` | required | Directory for output .dxnn and logs |
| `config` | `str` | `None` | Path to config.json (mutually exclusive with `dataloader`) |
| `dataloader` | `DataLoader` | `None` | PyTorch `torch.utils.data.DataLoader` (mutually exclusive with `config`). `batch_size` must be 1. |
| `calibration_method` | `str` | `"ema"` | `"ema"` or `"minmax"` |
| `calibration_num` | `int` | `100` | Number of calibration samples |
| `quantization_device` | `str` | `None` | Device for quantization. `None`=auto-detect (GPU if available), `"cpu"`, `"cuda"`, `"cuda:0"` |
| `opt_level` | `int` | `1` | Optimization level: 0 (minimal) or 1 (full) |
| `aggressive_partitioning` | `bool` | `False` | Maximize NPU operations |
| `input_nodes` | `List[str]` | `None` | Partial compilation: input node names |
| `output_nodes` | `List[str]` | `None` | Partial compilation: output node names |
| `enhanced_scheme` | `Dict` | `None` | Enhanced quantization config |
| `gen_log` | `bool` | `False` | Generate compiler.log |

### Mutual Exclusivity

`config` and `dataloader` are **mutually exclusive**. Provide exactly one:
- `config`: Path to config.json with `default_loader` section
- `dataloader`: Standard `torch.utils.data.DataLoader` instance with `batch_size=1`

If both are provided, DX-COM raises `ValueError`.
If neither is provided, DX-COM raises `ValueError`.

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
    quantization_device="cuda:0",
    opt_level=1,
    gen_log=True,
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
)
```

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

## Exceptions

| Exception | Cause |
|---|---|
| `FileNotFoundError` | Model or config path does not exist |
| `ValueError` | Both `config` and `dataloader` provided, or neither |
| `RuntimeError` | Compilation failure (unsupported op, shape mismatch, etc.) |
| `onnx.checker.ValidationError` | Invalid ONNX model |
