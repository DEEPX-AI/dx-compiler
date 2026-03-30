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

**Optimization Level Detail**  
The --opt_level option controls the optimization balance:  

- `0`: Fast compilation with basic optimizations. Reduces compilation time but may result in higher NPU latency.  
- `1` (Default): Full optimization for best performance. Compilation takes longer but provides optimal (lowest) NPU latency.  

**Aggressive Partitioning Detail (Experimental)**  
Enabling `--aggressive_partitioning` maximizes operations executed on the NPU. This feature is currently experimental and may produce unexpected results for some models.  

- **Benefit**: This is particularly advantageous in environments with limited host CPU performance (e.g., embedded systems, edge devices), as it significantly improves overall performance by minimizing CPU workload.  
- **Consideration**: In systems with powerful host CPUs, the compiler's default partitioning strategy might yield better end-to-end performance. Note that using this option may increase compilation time and memory usage.  

---

#### Debugging and Logging

These options are vital for troubleshooting, logging, and targeting specific sections of the model.  

| **Option** | **Shorthand** | **Description** |
| :--- | :--- | :--- |
| `--gen_log` | N/A | When enabled, the compiler collects all compilation logs into a `compiler.log` file in the specified output directory. Useful for debugging or analyzing the compilation process |
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

**Version Information**  
This command prints the compiler module version and exits.  
```
dxcom --version
```

**Compile Sample Models (Script)**  
For the end-to-end sample workflow, see [Quick Start Guide](00_Quick_Start.md#compile-sample-models). The `./example/3-compile_sample_models.sh` helper compiles `YOLOV5S-1`, `YOLOV5S_Face-1`, and `MobileNetV2-1` with `dxcom`, using assets prepared under `dx_com/`. If `dxcom` is not available in the current shell, the script first tries to activate the DX-COM virtual environment.  

---

## Python Wheel Package Usage

The Python wheel package also provides a programmatic interface for model compilation directly from Python code. This approach is particularly useful for automated workflows, multi-input models, and integration with existing Python pipelines.  

!!! note "Examples and Guides"
    For practical code examples and step-by-step guides, see:

    - [Quick Start Guide](00_Quick_Start.md)
    - [Common Use Cases](02_07_Common_Use_Cases.md)

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
    enhanced_scheme: Optional[Dict] = None,
    gen_log: bool = False,
) -> None
```

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
        # Return single sample or tuple of samples for multi-input models
        return self.data[idx]

dataset = CustomDataset()
dataloader = DataLoader(dataset, batch_size=1, shuffle=True)
```

---

### Optional Parameters

**`calibration_method`**

- **Type**: `str`
- **Default**: `"ema"`
- **Description**: Calibration method for quantization
- **Supported Values**: `"ema"` (Exponential Moving Average), `"minmax"` (Min-Max method)

```python
calibration_method="minmax"
```

**`calibration_num`**

- **Type**: `int`
- **Default**: `100`
- **Description**: Number of calibration samples to use for quantization

```python
calibration_num=200
```

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

```python
opt_level=1
```

**`aggressive_partitioning`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: **(Experimental)** Enable aggressive partitioning to maximize operations on NPU. This feature is currently experimental and may produce unexpected results for some models.
- **Use Case**: Beneficial for systems with limited host CPU performance

```python
aggressive_partitioning=True
```

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

**`gen_log`**

- **Type**: `bool`
- **Default**: `False`
- **Description**: Enable detailed logging for debugging

```python
gen_log=True
```

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

For more detailed examples — including DataLoader usage, multi-input models, edge device optimization, and advanced quantization — see [Common Use Cases](02_07_Common_Use_Cases.md).

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
