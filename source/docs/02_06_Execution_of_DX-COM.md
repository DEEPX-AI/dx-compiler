This section details the entire process for executing the DXNN Compiler (`dx_com`), which converts the prepared ONNX model (`*.onnx`) and configuration JSON file (`*.json`) into the optimized .dxnn output file. It covers everything from necessary prerequisites and fundamental command syntax to advanced options and troubleshooting.

---

## Execution Prerequisites and Constraints

**Model Input Limitation**  
The DXNN Compiler currently only supports ONNX models with a single input tensor.  
- Models featuring multiple input tensors **are not supported** and will fail compilation.  

**Calibration Data Requirements**  
The data used for model calibration must adhere to the following specifications:  

- **Default Data Type**: By default, the Calibration Data must consist of image files (e.g., JPEG, PNG).  
- **Custom Data**: If the use of non-image data types is required, a Custom Dataloader **must** be implemented and configured within the JSON File Configuration.  

**Non-Deterministic Output Notice**  
The compiled results may exhibit variation dependent on the underlying system environment, including CPU architecture, OS, and other specific hardware factors.  

---

## Compilation Execution

The compiler is executed via the command line, requiring the model, configuration, and desired output directory to generate the final `.dxnn` output file.  
 
**Command Format**  
```
dx_com -m <MODEL_PATH> -c <CONFIG_PATH> -o <OUTPUT_DIR> [OPTIONS]
```

**Required Arguments**  

| **Argument** | **Shorthand** | **Description** |
| :--- | :--- | :--- |
| `--model_path MODEL_PATH` | `-m` | Path to the ONNX Model file (`*.onnx`) |
| `--config_path CONFIG_PATH` | `-c` | Path to the Model Configuration JSON file (`*.json`) |
| `--output_dir OUTPUT_DIR` | `-o` | Directory to save the compiled model data |

---

## Advanced Compilation Options

The following optional arguments (`[OPTIONS]`) provide fine-grained control over the DXNN compilation process, allowing for performance tuning, resource management, and specialized debugging.

### Performance and Resource Control  

These options manage the balance between compilation time, NPU execution latency, and host CPU resource utilization.  

| **Option** | **Value/Default** | **Description** |
| :--- | :--- | :--- |
| `--opt_level` | `{0,1}` <br> (Default: `1`) | Controls the model optimization level during compilation | 
| `--aggressive_partitioning` | Flag | Enables partitioning designed to maximize operations executed on the NPU |

**Optimization Level Detail**  
The --opt_level option controls the optimization balance:  

- `0`: Fast compilation with basic optimizations. Reduces compilation time but may result in higher NPU latency.  
- `1` (Default): Full optimization for best performance. Compilation takes longer but provides optimal (lowest) NPU latency.  

Compiler Notification  
When using optimization level 1, the compiler automatically notifies the user of the potential time increase:  

```
[INFO] Using optimization level 1. Compilation may take longer.  
[INFO] For faster compilation, consider using --opt_level 0 (may increase NPU latency).  
```

**Aggressive Partitioning Detail**  
Enabling `--aggressive_partitioning` maximizes the offloading of operations to the NPU.  

- **Benefit**: This is particularly advantageous in environments with limited host CPU performance (e.g., embedded systems, edge devices), as it significantly improves overall performance by minimizing CPU workload.  
- **Consideration**: In systems with powerful host CPUs, the compiler's default partitioning strategy might yield better end-to-end performance. Note that using this option may increase compilation time and memory usage.  

---

### Debugging and Logging

These options are vital for troubleshooting, logging, and targeting specific sections of the model.  

| **Option** | **Shorthand** | **Description** |
| :--- | :--- | :--- |
| `--gen_log` | N/A | When enabled, the compiler collects all compilation logs into a `compiler.log` file in the specified output directory. Useful for debugging or analyzing the compilation process |
| `--version` | `-v` | Prints the compiler module version and exits |

**Partial Compilation (`--compile_input_nodes`, `--compile_output_nodes`)**  
These advanced options allow compiling only a specific subgraph of the ONNX model by defining starting and/or ending nodes.  

- `--compile_input_nodes`: Comma-separated list of node names where compilation should begin.  
- `--compile_output_nodes`: Comma-separated list of node names where compilation should end (compile up to).  

Use Cases: Debugging specific model sections, isolating problematic operations, and testing partial model compilation.  

!!! warning "Crucial Naming Requirement"  
    You **must** specify the ONNX Operator Node names (the operations/boxes in visualization tools like Netron), not the tensor/edge names (the lines connecting them).  

---

## Model Pre-processing and Execution Examples
The following examples demonstrate common usage patterns of the `dx_com` tool, from basic compilation to using advanced flags and pre-processing models.

### Model Pre-processing Requirement

**Batch Size Pre-processing Requirement**  
The `dx_com` tool strictly requires ONNX models with **a batch size fixed to 1.**  

If the input shape of the ONNX model is defined as (`batch_size, C, H, W`) where `batch_size` is variable or greater than 1, you **must** overwrite the batch size to 1 before compilation.  

- **Tool:** The `onnxsim` tool can be used for this simplification.  
- **Procedure:**  

```
pip install onnxsim

python3 -m onnxsim EfficientNet.onnx EfficientNet_sim.onnx 
--overwrite-input-shape 1,3,224,224
```

This command creates a new ONNX model (`EfficientNet_sim.onnx`) with the batch size fixed to **1**.  

---

### DXNN Compiler Execution Examples

**Command Line Examples**  

Basic Command   
This command compiles the model using the required model path (`-m`), config file (`-c`), and output directory (`-o`).  

```
./dx_com/dx_com \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1
```

With Log Generation  
This command uses the `--gen_log` flag to collect all compilation logs into `compiler.log` in the output directory.  

```
./dx_com/dx_com \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1 \
--gen_log
```

Aggressive Partitioning and Fast Compilation  
This combines `--aggressive_partitioning` to maximize NPU operations with `--opt_level 0` for faster compilation.  

```
./dx_com/dx_com \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1 \
--aggressive_partitioning \
--opt_level 0
```

Version Information  
This command prints the compiler module version and exits.  

```
./dx_com/dx_com --version
```

**Compile Sample Model with Makefile**  
If a Makefile is provided in the project, sample models can often be compiled directly:  

```
make MobileNetV1-1
```

This command typically compiles the `./sample/MobileNetV1-1.onnx` file and generates the output in the `./sample/MobileNetV1-1.dxnn` path.

---

## Output File Structure and Runtime

**Compiled Output File**  
Upon successful compilation, the DXNN Compiler generates a single output file named:  

```
{onnx_name}.dxnn
```

This file contains the compiled model data and is used as the input for the DX-RT runtime.  

**Example Output Directory**  
The following structure illustrates the typical organization of files after compiling a sample model using the `dx_com` tool:  

```
dx_com
├── calibration_dataset                  # Dataset used for calibration
...
├── dx_com                               # DXNN Compiler executable and libraries
...
├── output
│   └── mobilenetv1
│       └── MobilenetV1.dxnn              # Compiled output file
├── sample                                # Sample ONNX and JSON files
└── Makefile                              # Build script for compiling sample model
```

---

## Error Message During Compiling

This table describes common error types that may occur during the compilation process, along with their descriptions and examples of typical causes.  

| No | **Error Type** | **Description & Conditions** |
|----|---|---|
| 1  | NotSupportError | Triggered when using features unsupported by the compiler. <br> Examples: multi-input models, dynamic input shape, cubic resize |
| 2  | ConfigFileError | Invalid or missing JSON configuration file. <br> Examples: incorrect file path, malformed JSON syntax |
| 3  | ConfigInputError | Input definitions in the config file do not match the ONNX model. <br> Examples: mismatched input name or shape |
| 4  | DatasetPathError | The dataset path specified  in the configuration is invalid. <br> Examples: path does not exist, or is not a directory |
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
