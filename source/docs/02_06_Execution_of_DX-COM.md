With the ONNX and JSON files prepared, you can run the DXNN compiler to generate the  `.dxnn` output file.

### Notice to Execute

**Output Results Are Not Deterministic**  
The generated output `(.dxnn)` may vary depending on the system environment, such as CPU, OS, and other hardware factors. 

**Calibration Data Type**  
By default, Calibration Data must consist of image files.
Supported image formats are JPEG, PNG, and others.
If you need to support other data types, **Custom Dataloader** in **Secion 2.5 must** be implemented.

**No Support for Multiple-Input ONNX Models**  
ONNX models with multiple input tensors are currently not supported. 
Only models with a single input can be compiled. 

### How to Compile 
Use the following commands to generate the NPU Command Set and weights from a target ONNX model and configuration file.
 
**Command Format**
```
dx_com -m <MODEL_PATH> -c <CONFIG_PATH> -o <OUTPUT_DIR>
```

- `-m or --model_path MODEL_PATH`: Path to the ONNX Model file `(*.onnx)`.
- `-c or --config_path CONFIG_PATH`: Path to the Model Configuration JSON file `(*.json)`.
- `-o or --output_dir OUTPUT_DIR`: Directory to save the compiled model data.
- `-i or --info`(optional): Print internal module version information and exit.
- `-v or --version`(optional): Print compiler module version and exit.
- `--shrink`(optional): Generate a minimal output by including only the data essential for running on the NPU

If you want to reduce the file size of the compiled output, use the --shrink option. This ensures the output file contains only the components required for running the NPU execution, excluding debug and intermediate files.

**Note.** Despite using the same ONNX file in the same PC environment, dx_com may produce different outputs due to internal kernel behavior during optimization and compilation.


**Command Examples**

Basic Command
```
./dx_com/dx_com \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1
```

Using `--shrink` Option
```
./dx_com/dx_com \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1 \
--shrink
```

This will generate a minimal output containing only the components essential for NPU execution.


**Compile Sample Model with Makefile**  

You can compile the sample model using the provided Makefile.
```
make mv1 
```

This command will compile the `mobilenetv1` sample and generate the output in `./output/mobilenetv1`.  
 
**Note.** `dx_com` supports ONNX models with batch size fixed to 1 only. If the input shape of the ONNX model is defined as `(batch_size, C, H, W)`, you must overwrite the batch size to 1 before compilation.
```
pip install onnxsim

python3 -m onnxsim EfficientNet.onnx EfficientNet_sim.onnx --overwrite-input-shape 1,3,224,224
```

This will create a new ONNX model `(EfficientNet_sim.onnx)` with the batch size set to 1.


**Output File Structure**  

After a successful compilation, the DXNN Compiler generates a single output file named
```
{onnx_name}.dxnn
```

This file contains the compiled model and is used as input for both **DX-SIM** and **DX-RT** processes. 


`Example Output Directory Structure`  

After compiling a sample model using the dx_com tool, your project directory may look like this.
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

### Error Message During Compiling  

This section describes common error types that may occur during the compilation process, along with their descriptions and examples of typical causes. 


| No | **Error Type**  | **Description & Conditions**  |
|----|-----------------|-------------------------------|
| 1  | NotSupportError  | Triggered when using features unsupported by the compiler. <br> Examples: multi-input models, dynamic input shape, cubic resize  |
| 2  | ConfigFileError  | Invalid or missing JSON configuration file. <br> Examples: incorrect file path, malformed JSON syntax   |
| 3  | ConfigInputError  | Input definitions in the config file do not match the ONNX model. <br> Examples: mismatched input name or shape  |
| 4  | DatasetPathError   | The dataset path specified  in the configuration is invalid. <br> Examples: path does not exist, or is not a directory  |
| 5  | NodeNotFoundError  | The ONNX model contains a node that is unsupported by the compiler.  |
| 6  | OSError  | The operating system is unsupported. <br> Examples: OS is not Ubuntu   |
| 7  | UbuntuVersionError  | The installed Ubuntu version is outside the supported range.  |
| 8  | LDDVersionError  | The installed `ldd` version is unsupported.  |
| 9  | RamSizeError  | The system does not meet the minimum RAM requirements.  |
| 10 | DiskSizeError   | Available disk space is insufficient for compilation.  |
| 11 | NotsupportedPaddingError  | Padding configuration is unsupported. <br> Examples: asymmetric padding in width and height   |
| 12 | RequiredLibraryError  | Missing essential system libraries. <br> Examples: `libgl1-mesa-glx` is not installed  |
| 13 | DataNotFoundError  | No valid input data found in the specified dataset path. <br> Examples: empty folder, wrong file extensions  |
| 14 | OnnxFileNotFound  | The ONNX model file cannot be found or does not exist at the specified location.  |

---
