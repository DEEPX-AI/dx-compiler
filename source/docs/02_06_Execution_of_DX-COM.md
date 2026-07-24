This section details the entire process for executing the DXNN Compiler, which converts the prepared ONNX model (`*.onnx`) and configuration JSON file (`*.json`) into the optimized `.dxnn` output file. You can use DX-COM through both the `dxcom` command-line interface and the `dx_com` Python module.

**DX-COM** supports two execution methods:  

- **[CLI Execution](#cli-execution-command-line-interface)**: Execute compilation using the `dxcom` command with configuration files  
- **[dx_com Python Module](#python-wheel-package-usage)**: Programmatic compilation using the `dx_com` Python module with torch DataLoader  

Choose the execution method that best fits your workflow and model requirements.

---

## Execution Prerequisites and Constraints

**Calibration Data Requirements**  
The data used for model calibration must adhere to the following specifications:

- **Default Data Type**: By default, the Calibration Data must consist of image files (e.g., JPEG, PNG).
- **Custom Data**: If the use of non-image data types is required, use the `dx_com` Python module with a custom torch DataLoader.

**Multi-Input Model Support**  
Multi-input models are now supported through the `dx_com` Python module using torch DataLoader. For command-line execution, only single-input models are supported.

**Non-Deterministic Output Notice**  
The compiled results may exhibit variation dependent on the underlying system environment, including CPU architecture, OS, and other specific hardware factors.

---

## CLI Execution (Command-Line Interface)

The compiler can be executed via the `dxcom` command, requiring the model, configuration, and desired output directory to generate the final `.dxnn` output file.

!!! note "Execution Method"
    Use the `dxcom` command for command-line compilation.

### Basic Command

**Using `dxcom`:**
```bash
dxcom -m model.onnx -c config.json -o output/
```

**What you need**:

- `model.onnx` - Your pre-trained model
- `config.json` - Configuration file (see [JSON File Configuration](02_05_JSON_File_Configuration.md))
- `calibration_dataset/` - Folder with calibration images (referenced in config.json)

---

### Command Format

```
dxcom -m <MODEL_PATH> -c <CONFIG_PATH> -o <OUTPUT_DIR> [OPTIONS]
```

**Required Arguments**  

| **Argument** | **Shorthand** | **Description** |
| :--- | :--- | :--- |
| `--model_path MODEL_PATH` | `-m` | Path to the ONNX Model file (`*.onnx`) |
| `--config_path CONFIG_PATH` | `-c` | Path to the Model Configuration JSON file (`*.json`) |
| `--output_dir OUTPUT_DIR` | `-o` | Directory to save the compiled model data |

---

### Advanced Compilation Options

The following optional arguments (`[OPTIONS]`) provide fine-grained control over the DXNN compilation process, allowing for performance tuning, resource management, and specialized debugging.

#### Performance and Resource Control  

These options manage the balance between compilation time, NPU execution latency, and host CPU resource utilization.  

| **Option** | **Value/Default** | **Description** |
| :--- | :--- | :--- |
| `--opt_level` | `{0,1}` <br> (Default: `1`) | Controls the model optimization level during compilation | 
| `--aggressive_partitioning` | Flag | **(Experimental)** Enables partitioning designed to maximize operations executed on the NPU |
| `--float64_calibration` | Flag | Use float64 precision during calibration and offset calculations for cross-CPU determinism |

**Optimization Level Detail**  
The --opt_level option controls the optimization balance:  

- `0`: Fast compilation with basic optimizations. Reduces compilation time but may result in higher NPU latency.  
- `1` (Default): Full optimization for best performance. Compilation takes longer but provides optimal (lowest) NPU latency.  

**Aggressive Partitioning Detail (Experimental)**  
Enabling `--aggressive_partitioning` maximizes operations executed on the NPU. This feature is currently experimental and may produce unexpected results for some models.  

- **Benefit**: This is particularly advantageous in environments with limited host CPU performance (e.g., embedded systems, edge devices), as it significantly improves overall performance by minimizing CPU workload.  
- **Consideration**: In systems with powerful host CPUs, the compiler's default partitioning strategy might yield better end-to-end performance. Note that using this option may increase compilation time and memory usage.  

---

#### Quantization Quality and Tuning

These options control quantization accuracy enhancement and the diagnose → re-quantize tuning loop. Available in **DX-COM v2.4.0 and later**.

| **Option** | **Value/Default** | **Description** |
| :--- | :--- | :--- |
| `--use_q_pro` | Flag | Enable the automatic Q-PRO quantization pipeline (ONNX compile path only). Mutually exclusive with a manual `enhanced_scheme`. |
| `--quant_diagnosis` | Flag | Produce a per-region quantization diagnosis report (`quant_diagnosis/diagnosis_report.html`) and a reusable resume checkpoint (`quant_diagnosis/{model}.qxnn`). |
| `--checkpoint` | `<path>.qxnn` | Path to a `.qxnn` resume artifact. Selects **QXNN resume** mode (re-quantize without recompile). Mutually exclusive with `-m/--model_path`. |
| `--recalibration_method` | `{minmax,ema,iqr}` | **(Resume-only)** Observer override applied during re-calibration. |
| `--enhanced_scheme` | e.g. `P3:num_samples=2048` | **(Resume-only)** Manual Q-PRO scheme selection. Mutually exclusive with `--use_q_pro`. |
| `--dataset_path` | Path | **(Resume-only)** Override the calibration dataset path embedded in the checkpoint. |

For automatic Q-PRO details see [Automatic Q-PRO (`use_q_pro`)](#automatic-q-pro-use_q_pro) below. For the full diagnose → resume workflow, see [Quantization Tuning Workflow](02_07_Quantization_Tuning_Workflow.md).

##### Automatic Q-PRO (`use_q_pro`)

When quantization accuracy degrades, Q-PRO enhancement schemes (DXQ-P0 to DXQ-P5) can improve it. The `enhanced_scheme` JSON field exposes these schemes for **manual** selection (see [Enhanced Quantization Scheme (DXQ)](02_05_JSON_File_Configuration.md#optional-parameters-enhanced-quantization-scheme-dxq)). The `--use_q_pro` flag is the **automatic** alternative: DX-COM generates DXQ combinations and selects the optimal enhancement stages based on model structure and compile-time metrics — no manual tuning required.

```bash
# dxcom CLI
dxcom -m model.onnx -c config.json -o ./output --use_q_pro
```
```python
# dx_com Python module
import dx_com
dx_com.compile(model="model.onnx", output_dir="./output", config="config.json", use_q_pro=True)
```

- **Mutually exclusive** with a manual `enhanced_scheme` — choose one, not both.
- Can also be enabled while re-quantizing via [QXNN Resume](02_07_Quantization_Tuning_Workflow.md#qxnn-resume-re-quantization-without-recompile).

!!! tip "Automatic vs Manual"
    Prefer `--use_q_pro` for the easiest path to higher-accuracy quantization. Drop down to a manual `enhanced_scheme` only when you need to pin a specific DXQ scheme.

---

#### Debugging and Logging

These options are vital for troubleshooting, logging, and targeting specific sections of the model.  

| **Option** | **Shorthand** | **Description** |
| :--- | :--- | :--- |
| `--gen_log` | N/A | When enabled, the compiler collects all compilation logs into a `compiler.log` file in the specified output directory. Useful for debugging or analyzing the compilation process |
| `--export_html` | N/A | Generate a self-contained HTML summary report (`<model_name>_summary.html`) in the output directory after compilation. See [Compilation Summary Report](04_02_Compilation_Summary_Report.md) |
| `--version` | `-v` | Prints the compiler module version and exits |

**Partial Compilation (`--compile_input_nodes`, `--compile_output_nodes`)**  
These advanced options allow compiling only a specific subgraph of the ONNX model by defining starting and/or ending nodes.  

- `--compile_input_nodes`: Comma-separated list of node names where compilation should begin.  
- `--compile_output_nodes`: Comma-separated list of node names where compilation should end (compile up to).  

**Use Cases:** Debugging specific model sections, isolating problematic operations, and testing partial model compilation.  

!!! warning "Crucial Naming Requirement"  
    You **must** specify the ONNX Operator Node names (the operations/boxes in visualization tools like Netron), not the tensor/edge names (the lines connecting them).  

---

### CLI Execution Examples

The following examples demonstrate common usage patterns for CLI compilation.  

**Basic Command**     
This command compiles the model using the required model path (`-m`), config file (`-c`), and output directory (`-o`).  
```
dxcom \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1
```

**With Log Generation**  
This command uses the `--gen_log` flag to collect all compilation logs into `compiler.log` in the output directory.  
```
dxcom \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1 \
--gen_log
```

**With HTML Summary Report**  
This command adds the `--export_html` flag to also generate `<model_name>_summary.html` in the output directory.  
```bash
dxcom \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1 \
--export_html
```

**Version Information**  
This command prints the compiler module version and exits.  
```
dxcom --version
```

**With Quantization Diagnosis**  
This command enables `--quant_diagnosis` to produce a per-region diagnosis report and a `.qxnn` resume checkpoint under `quant_diagnosis/` in the output directory.  
```
dxcom \
-m large_model.onnx \
-c config.json \
-o output/large_model \
--quant_diagnosis
```

**Re-quantize from a Checkpoint (QXNN Resume)**  
This command re-runs quantization from a `.qxnn` checkpoint with a different calibration observer, skipping the earlier compile phases. No `-m`/`-c` is required.  
```
dxcom \
--checkpoint output/large_model/quant_diagnosis/large_model.qxnn \
-o output/large_model_iqr \
--recalibration_method iqr
```

See [Quantization Tuning Workflow](02_07_Quantization_Tuning_Workflow.md) for the full diagnose → resume loop.

**Compile Sample Models (Script)**  
For the end-to-end sample workflow, see [Quick Start Guide](00_Quick_Start.md#compile-sample-models). The `./example/3-compile_sample_models.sh` helper compiles `YOLOV5S-1`, `YOLOV5S_Face-1`, and `MobileNetV2-1` with `dxcom`, using assets prepared under `dx_com/`. If `dxcom` is not available in the current shell, the script first tries to activate the DX-COM virtual environment.  

---

## Python Wheel Package Usage

The Python wheel package also provides a programmatic interface for model compilation directly from Python code. This approach is particularly useful for automated workflows, multi-input models, and integration with existing Python pipelines.  

!!! note "Examples and Guides"
    For practical code examples and step-by-step guides, see:

    - [Quick Start Guide](00_Quick_Start.md)
    - [Common Use Cases](02_08_Common_Use_Cases.md)
    - [Pre-Optimize API](02_09_Pre_Optimize_API.md) for `dx_com.pre_optimize()`, an ONNX-level transform that reduces CPU-side post-processing for YOLO-family models before compilation.

### Overview

The `dx_com.compile()` function is the main entry point for compilation. It performs quantization, optimization, partitioning, and generates compiled artifacts including the `.dxnn` file.

---

### Function Signature

```python
def compile(
    model: Union[str, onnx.ModelProto],
    output_dir: str,
    config: Optional[str] = None,
    dataloader: Optional[DataLoader] = None,
    calibration_method: str = "ema",
    calibration_num: int = 100,
    quantization_device: Optional[str] = None,
    opt_level: int = 1,
    aggressive_partitioning: bool = False,
    input_nodes: Optional[List[str]] = None,
    output_nodes: Optional[List[str]] = None,
    use_q_pro: bool = False,
    enhanced_scheme: Optional[Dict] = None,
    ppu_config: Optional[PPUConfig] = None,
    gen_log: bool = False,
    float64_calibration: bool = False,
    export_html: bool = False,
    quantization_mode: str = "ptq",
    qat_config: Optional[Dict] = None,
    qat_skip_training: bool = False,
    qat_resume_from_checkpoint: Optional[str] = None,
) -> None
```

!!! note "Additional Parameters"
    The signature above lists the most commonly used parameters. `dx_com.compile()`
    accepts further advanced/diagnostic parameters (e.g. `quant_diagnosis`,
    `super_debug`, `checkpoint` for QXNN resume). See the function docstring
    (`help(dx_com.compile)`) for the complete list.

---

### Required Parameters

**`model`**

- **Type**: `Union[str, onnx.ModelProto]`
- **Description**: The ONNX model to compile

    - Can be a file path string to an ONNX model file
    - Or a pre-loaded `onnx.ModelProto` object

```python
# Using file path
model="path/to/model.onnx"

# Using ModelProto object
import onnx
model = onnx.load("path/to/model.onnx")
```

**`output_dir`**

- **Type**: `str`
- **Description**: Directory where compiled artifacts will be saved (e.g., `.dxnn` file)

```python
output_dir="./compiled-model"
```

**`config` or `dataloader`** (one must be provided)

**`config`**

- **Type**: `Optional[str]`
- **Default**: `None`
- **Description**: Path to JSON configuration file containing calibration and compilation settings
- **Mutually exclusive**: Cannot be used together with `dataloader`

```python
config="path/to/config.json"
```

**`dataloader`**

- **Type**: `Optional[DataLoader]`
- **Default**: `None`
- **Description**: PyTorch DataLoader providing calibration data
- **Use Case**: Useful for multi-input models and programmatic data provision
- **Requirement**: `batch_size` must be set to 1
- **Mutually exclusive**: Cannot be used together with `config`

```python
from torch.utils.data import Dataset, DataLoader

class CustomDataset(Dataset):
    def __init__(self):
        # Initialize your dataset
        pass
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        # Single-input: return one tensor.
        # Multi-input: return a dict keyed by ONNX input node name (recommended).
        return self.data[idx]

dataset = CustomDataset()
dataloader = DataLoader(dataset, batch_size=1, shuffle=True)
```

#### Defining Preprocessing Transforms in the DataLoader

When you compile with a `dataloader`, the JSON `default_loader.preprocessings` block is **not** used. All preprocessing (resize, color conversion, normalization, layout) must be applied **inside the Dataset's `__getitem__`**, so that each tensor the DataLoader yields is already in the exact shape and value range the ONNX model expects.

!!! warning "Calibration must match deployment preprocessing"
    The transform applied here **must match the preprocessing used at inference time**. A mismatch (e.g. different mean/std, wrong channel order, missing `/255`) degrades calibration quality and post-quantization accuracy.

**Two common ways to define transforms:**

**1. `torchvision.transforms` (PIL-based, recommended for image models):**
```python
from torchvision import transforms
from PIL import Image

transform = transforms.Compose([
    transforms.Resize((224, 224)),                 # resize
    transforms.ToTensor(),                         # HWC uint8 -> CHW float in [0,1] (implicit /255)
    transforms.Normalize(                          # normalize
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225],
    ),
])

def __getitem__(self, idx):
    image = Image.open(self.image_files[idx]).convert("RGB")  # RGB channel order
    return transform(image)                                   # shape [3, 224, 224]
```

**2. OpenCV + manual NumPy/torch (when you need exact control):**
```python
import cv2
import numpy as np
import torch

def __getitem__(self, idx):
    img = cv2.imread(self.image_files[idx])            # BGR, HWC
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)         # convertColor BGR2RGB
    img = cv2.resize(img, (224, 224))                  # resize
    img = img.astype(np.float32) / 255.0               # div: x=255
    mean = np.array([0.485, 0.456, 0.406], np.float32)
    std = np.array([0.229, 0.224, 0.225], np.float32)
    img = (img - mean) / std                           # normalize
    img = np.transpose(img, (2, 0, 1))                 # HWC -> CHW (transpose)
    return torch.from_numpy(img)                       # shape [3, 224, 224]
```

**Mapping JSON `preprocessings` to DataLoader transforms:**

The `default_loader` reads each image with `cv2.imread` (**BGR**, `HWC`, `uint8`) and applies the operations below in order. When you write a custom `dataloader` you must reproduce the same chain by hand. The table lists every operation in the preprocessing registry and its `key: {args}` form.

| JSON operation | Arguments | DataLoader equivalent |
|----------------|-----------|-----------------------|
| `resize` | `width`, `height` (or `size`, `mode`) | `cv2.resize(...)` / `transforms.Resize(...)` |
| `resize2` / `resize3` / `resize_tv` | resize variants (`mlcommons` / `scale` / `torchvision` mode) | matching resize logic |
| `centercrop` / `centercrop2` | `width`, `height` | `img[top:top+h, left:left+w]` / `transforms.CenterCrop(...)` |
| `convertColor` | `form` (e.g. `BGR2RGB`) | `cv2.cvtColor(...)` / `Image.convert("RGB")` |
| `div` | `x` (scalar or per-channel list) | `img / x` (`div:{x:255}` ≈ `transforms.ToTensor()`) |
| `mul` | `x` | `img * x` |
| `subtract` | `x` | `img - x` |
| `add` | `x` | `img + x` |
| `normalize` | `mean`, `std` (lists) | `(img - mean) / std` / `transforms.Normalize(...)` |
| `transpose` | `axis` (e.g. `[2,0,1]`) | `np.transpose(img, axis)` / `tensor.permute(...)` |
| `expandDim` | `axis` | `np.expand_dims(...)` / `tensor.unsqueeze(axis)` |
| `squeeze` | `axis` | `np.squeeze(...)` / `tensor.squeeze(axis)` |
| `slice` | `channel` | `img[..., channel]` |
| `dtype` | `t` (numpy dtype) | `img.astype(t)` |
| `pil_2_cv` | — | PIL→numpy BGR conversion |

!!! note "Output shape, dtype, and batch size"
    The compiler runs the verifier on `next(iter(dataloader))` and requires the **batched** sample shape to match the ONNX input shape **exactly**, including the batch dimension. So each `__getitem__` item must be `model_input_shape` without the leading batch dim (e.g. `[3, 224, 224]` for input `[1, 3, 224, 224]`), and `batch_size` must equal the model's input batch (normally `1`). Tensors should be `float32`.

!!! note "Supported return types"
    Each `__getitem__` may return: a single `torch.Tensor` (single-input models), a **`dict[str, torch.Tensor]`** keyed by ONNX input node name (**recommended for multi-input** — mapped by name), or a **list/tuple of tensors** (mapped by the model's internal input-node order, which may differ from your return order). All elements must be tensors. See [Use Case 2](02_08_Common_Use_Cases.md#use-case-2-multi-input-models-stereo-vision).

---

### Optional Parameters

**`calibration_method`**

- **Type**: `str`
- **Default**: `"ema"`
- **Description**: Calibration method for quantization
- **Supported Values**: `"ema"` (Exponential Moving Average), `"minmax"` (Min-Max method)

**`calibration_num`**

- **Type**: `int`
- **Default**: `100`
- **Description**: Number of calibration samples to use for quantization

**`quantization_device`**

- **Type**: `Optional[str]`
- **Default**: `None` (auto-detect: uses GPU if available, otherwise CPU)
- **Description**: Device for quantization computation
- **Supported Values**: `None` (auto-detect), `"cpu"`, `"cuda"`, `"cuda:0"`, `"cuda:1"`, etc.

```python
quantization_device="cuda"  # Use GPU
quantization_device="cuda:1"  # Use specific GPU
```

**`opt_level`**

- **Type**: `int`
- **Default**: `1`
- **Description**: Optimization level
- **Supported Values**:

    - `0`: Fast compilation with basic optimizations
    - `1`: Full optimization (recommended) - provides best performance but takes longer

**`aggressive_partitioning`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: **(Experimental)** Enable aggressive partitioning to maximize operations on NPU. This feature is currently experimental and may produce unexpected results for some models.
- **Use Case**: Beneficial for systems with limited host CPU performance

**`input_nodes`**

- **Type**: `Optional[List[str]]`
- **Default**: `None`
- **Description**: List of entry node names for subgraph compilation
- **Note**: Must specify ONNX operator node names (not tensor names)

```python
input_nodes=["Conv12", "Conv13"]
```

**`output_nodes`**

- **Type**: `Optional[List[str]]`
- **Default**: `None`
- **Description**: List of exit node names for subgraph compilation
- **Note**: Must specify ONNX operator node names (not tensor names)

```python
output_nodes=["Conv123", "Conv124"]
```

**`enhanced_scheme`**

- **Type**: `Optional[Dict]`
- **Default**: `None`
- **Description**: Advanced quantization scheme for improved accuracy
- **Limitation**: Not supported for multi-input models
- **Supported Schemes**: `"DXQ-P0"` through `"DXQ-P5"`

```python
enhanced_scheme={
    "DXQ-P0": {"alpha": 0.5},
    "DXQ-P2": {
        "alpha": 0.1,
        "beta": 1.0,
        "cosim_num": 2,
    },
}
```

**`use_q_pro`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Enable the automatic Q-PRO quantization optimization pipeline. The compiler auto-selects and applies the optimal combination of enhancement stages based on model structure.
- **Limitation**: Mutually exclusive with `enhanced_scheme` (set only one). ONNX compile path only.

**`ppu_config`**

- **Type**: `Optional[PPUConfig]`
- **Default**: `None` (PPU disabled)
- **Description**: PPU (Post-Processing Unit) configuration object that enables hardware-accelerated post-processing for YOLO-family object detection models. It is the Python-module equivalent of the JSON `ppu` section (see [PPU Configuration](02_05_JSON_File_Configuration.md#optional-parameters-ppu-configuration)).
- **Requirement**: Must be a `PPUConfig` instance. `compile()` calls `ppu_config.validate()` and raises if required fields are missing.

Import `PPUConfig` and `PPUTypes` from the top-level `dx_com` package:

```python
from dx_com import PPUConfig, PPUTypes
```

`PPUTypes` maps to the JSON `type` field:

| `PPUTypes` | Value | Architecture | Models |
|------------|-------|--------------|--------|
| `PPUTypes.YOLO_BASE` | 0 | Anchor-Based | YOLOv3/v4/v5/v7 |
| `PPUTypes.YOLO_ANCHORFREE` | 1 | Anchor-Free | YOLOX, YOLOv8–v12 |
| `PPUTypes.YOLOV8` | 2 | DFL-Based (CPU TopK) | YOLOv8–v12 |

**Construction patterns** — full init or incremental builder (chainable setters):

```python
# Type 0 (anchor-based) — full init
cfg = PPUConfig(
    type=PPUTypes.YOLO_BASE,
    conf_thres=0.25,
    activation="Sigmoid",
    num_classes=80,
    layer={
        "Conv_245": {"num_anchors": 3},
        "Conv_294": {"num_anchors": 3},
        "Conv_343": {"num_anchors": 3},
    },
)

# Type 0 (anchor-based) — incremental builder
cfg = (
    PPUConfig()
    .set_type(PPUTypes.YOLO_BASE)
    .set_num_classes(80)
    .set_activation("Sigmoid")
    .set_conf_thres(0.25)
)
cfg.add_layer("Conv_245", num_anchors=3)
cfg.add_layer("Conv_294", num_anchors=3)
cfg.add_layer("Conv_343", num_anchors=3)


# Type 1 (anchor-free) — incremental builder
cfg = (
    PPUConfig()
    .set_type(PPUTypes.YOLO_ANCHORFREE)
    .set_num_classes(80)
    .set_conf_thres(0.25)
)
cfg.add_layer(bbox="Mul_441", cls_conf="Sigmoid_442")

# Type 2 (DFL-based, CPU-side TopK)
cfg = PPUConfig(type=PPUTypes.YOLOV8, num_classes=80, topk=512)
cfg.add_layer(bbox="bbox_head_p3", cls_conf="cls_head_p3")
cfg.add_layer(bbox="bbox_head_p4", cls_conf="cls_head_p4")
cfg.add_layer(bbox="bbox_head_p5", cls_conf="cls_head_p5")
```

`PPUConfig` builder methods:

| Method | Purpose |
|--------|---------|
| `set_type(PPUTypes.*)` | Set PPU type (resets `layer`) |
| `set_num_classes(int)` | Set number of detection classes |
| `set_conf_thres(float)` | Set confidence threshold (type 0/1) |
| `set_activation(str)` | Set activation, e.g. `"Sigmoid"` (type 0) |
| `set_topk(int)` | Set TopK candidate count (type 2) |
| `add_layer(...)` | Add a detection head; signature depends on type |
| `validate()` | Validate required fields (called by `compile()`) |

!!! note "`add_layer` signature by type"
    - **Type 0**: `add_layer("Conv_245", num_anchors=3)` — `layer` is a dict.
    - **Type 1 / 2**: `add_layer(bbox="...", cls_conf="...")` (optional `obj_conf=`) — `layer` is a list. Call once per detection scale.

See [Use Case 8: PPU Hardware Acceleration](02_08_Common_Use_Cases.md#use-case-6-ppu-hardware-acceleration-yolo) for a complete script.

**`gen_log`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Enable detailed logging for debugging

**`float64_calibration`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Use float64 precision during calibration and offset calculations for cross-CPU determinism

**`export_html`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Generate a self-contained HTML summary report (`<model_name>_summary.html`) in the output directory after compilation. See [Compilation Summary Report](04_02_Compilation_Summary_Report.md) for details.

**`use_q_pro`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Enable the automatic Q-PRO quantization pipeline. DX-COM automatically selects and applies the optimal DXQ enhancement stages.
- **Limitation**: Mutually exclusive with `enhanced_scheme`.
- **See also**: [Automatic Q-PRO (`use_q_pro`)](02_06_Execution_of_DX-COM.md#automatic-q-pro-use_q_pro)

**`quant_diagnosis`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Generate an HTML quantization diagnosis report. Produces `{output_dir}/quant_diagnosis/{model}.qxnn` (resume checkpoint) and `{output_dir}/quant_diagnosis/diagnosis_report.html`.
- **See also**: [Quantization Tuning Workflow](02_07_Quantization_Tuning_Workflow.md)

**`checkpoint`** *(QXNN Resume)*

- **Type**: `Optional[str]`
- **Default**: `None`
- **Description**: Path to a `.qxnn` resume artifact. When provided, selects the **QXNN resume** path, which re-runs quantization without recompiling. The `model`/`config` arguments are not required in this mode.
- **Related parameters** (resume-only): `recalibration_method` (`"minmax"`/`"ema"`/`"iqr"`), `dataset_path`, and `enhanced_scheme`.

```python
import dx_com

dx_com.compile(
    checkpoint="output/large_model/quant_diagnosis/large_model.qxnn",
    output_dir="output/large_model_iqr",
    recalibration_method="iqr",   # or: use_q_pro=True
)
```
**`quantization_mode`**

- **Type**: `str`
- **Default**: `"ptq"`
- **Description**: Quantization mode. The default `"ptq"` runs Post-Training Quantization. When the config JSON contains a `qmaster` block, QAT is **auto-selected** — you do not need to pass this argument. Set to `"qat"` explicitly only when supplying `qat_config` directly in Python; doing so bypasses `qmaster` auto-detection. When set to `"qat"`, you must provide either `qat_config` (for training) or `qat_skip_training=True` (for compile-only/resume).
- **Supported Values**: `"ptq"`, `"qat"`

**`qat_config`**

- **Type**: `Optional[Dict]`
- **Default**: `None`
- **Description**: QAT training hyperparameters. Usually supplied via the `qmaster` block in the config JSON instead of this argument.

**`qat_skip_training`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Skip the QAT training loop and run compilation only. Use together with `qat_resume_from_checkpoint`.

**`qat_resume_from_checkpoint`**

- **Type**: `Optional[str]`
- **Default**: `None`
- **Description**: Path to a saved `qat_checkpoint.qxnn` to load trained weights before compilation.

!!! note "QAT Details"
    For the full QAT workflow, the `qmaster` block, and all training hyperparameters,
    see [Quantization-Aware Training (QAT)](02_08_Quantization_Aware_Training.md).

---

### Return Value

- **Type**: `None`
- **Behavior**: Compiled artifacts are saved to the specified `output_dir`

---

### Usage Examples

**Basic Compilation with Configuration File**

```python
import dx_com

dx_com.compile(
    model="model.onnx",
    output_dir="./compiled",
    config="config.json",
)
```

For more detailed examples — including DataLoader usage, multi-input models, edge device optimization, and advanced quantization — see [Common Use Cases](02_08_Common_Use_Cases.md).

---

### Important Considerations

!!! warning "Input Selection: Config vs DataLoader"
    Users must provide **either** a configuration file **or** a DataLoader. These inputs are mutually exclusive.

    - **Config:** Recommended for static, file-based compilation workflows.
    - **DataLoader:** Required for programmatic data provision and models with multiple inputs.
    When constructing a DataLoader for compilation, the **batch_size must be set to 1.**

!!! note "Hardware Acceleration (CUDA)"
    To enable GPU-accelerated quantization (quantization_device="cuda"), ensure the following requirements are met:

    - **System:** NVIDIA CUDA drivers and toolkit are installed.
    - **Framework:** PyTorch is built with CUDA support (torch.cuda.is_available() is True).

!!! note "Deprecation Notice: CustomLoader"
    The legacy CustomLoader for non-image data is **deprecated.**

    - **New Standard:** Use the standard **PyTorch DataLoader** for all data modalities (Image, Tensor, etc.) to ensure long-term compatibility and performance.

---

### Output Files

Upon successful compilation, the `output_dir` will contain:

- `[model_name].dxnn`: Compiled model binary for execution on DEEPX NPU hardware
- `compiler.log` (if `gen_log=True`): Detailed compilation logs
- `[model_name]_summary.html` (if `--export_html` / `export_html=True`): Self-contained HTML compilation summary report

---

## Common Errors and Troubleshooting

The following error types may occur during the compilation process using either the `dxcom` command or the `dx_com` Python module. Understanding these errors will help you troubleshoot issues regardless of which interface you choose.

| No | **Error Type** | **Description & Conditions** |
|----|---|---|
| 1  | NotSupportError | Triggered when using features unsupported by the compiler. <br> Examples: multi-input models with the `dxcom` command, dynamic input shape, cubic resize |
| 2  | ConfigFileError | Invalid or missing JSON configuration file. <br> Examples: incorrect file path, malformed JSON syntax |
| 3  | ConfigInputError | Input definitions in the config file do not match the ONNX model. <br> Examples: mismatched input name or shape |
| 4  | DatasetPathError | The dataset path specified in the configuration is invalid. <br> Examples: path does not exist, or is not a directory |
| 5  | NodeNotFoundError | The ONNX model contains a node that is unsupported by the compiler |
| 6  | OSError | The operating system is unsupported. <br> Examples: OS is not Ubuntu |
| 7  | UbuntuVersionError | The installed Ubuntu version is outside the supported range |
| 8  | LDDVersionError | The installed `ldd` version is unsupported |
| 9  | RamSizeError | The system does not meet the minimum RAM requirements |
| 10 | DiskSizeError | Available disk space is insufficient for compilation |
| 11 | NotsupportedPaddingError | Padding configuration is unsupported. <br> Examples: asymmetric padding in width and height |
| 12 | RequiredLibraryError | Missing essential system libraries. <br> Examples: `libgl1-mesa-glx` is not installed |
| 13 | DataNotFoundError | No valid input data found in the specified dataset path. <br> Examples: empty folder, wrong file extensions |
| 14 | OnnxFileNotFound | The ONNX model file cannot be found or does not exist at the specified location |

---
