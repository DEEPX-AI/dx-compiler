The source structure of **DX-COM** is organized as follows. The structure is the same for both Executable and Python Wheel distributions, with some items specific to each distribution type.  

```
dx_com/
├── LICENSE
├── RELEASE_NOTES.md
├── calibration_dataset/       # Dataset for model accuracy optimization
├── dx_com/                    # (Executable File distribution only)
│  ├── cv2/                    # Third-party libraries (OpenCV, etc.)
│  ├── google/                 # Third-party libraries (protobuf, etc.)
│  ├── numpy/                  # Third-party libraries (NumPy, etc.)
│  ├── ...                     # Other dependencies
│  └── dx_com                  # Core compiler executable
├── dx_com-*.whl               # (Python Wheel distribution only)
├── sample/
│  ├── MobilenetV1.json        # Sample configuration file
│  └── MobilenetV1.onnx        # Sample ONNX model
└── Makefile                   # (Executable File distribution only)
```

**LICENSE**  
License file for DX-COM.  

**RELEASE_NOTES.md**  
Release notes for the current version, including new features, bug fixes, and known issues.  

**calibration_dataset**  
This directory contains the calibration dataset used for compiling the included sample model as an example. It is used to calibrate the model's input range for quantization purposes.  
If the calibration dataset does not reflect the training or field data, it may significantly degrade model accuracy.  

**dx_com/** (Executable File distribution)  
This directory contains executable files and shared libraries used to generate NPU command sets from ONNX models. It includes the core compiler logic and third-party dependencies such as OpenCV, NumPy, and Protobuf.  

**dx_com-*.whl** (Python Wheel distribution)  
This Python wheel package contains the compiled `dx_com` module for programmatic use. After extraction, install it using `pip install dx_com-*.whl` to use the Python API. Refer to [Installation of DX-COM](02_02_Installation_of_DX-COM.md#option-2-python-wheel-package) for installation instructions.  

**sample**  
This folder provides example files to demonstrate how to compile an ONNX model using **DX-COM**.  

- **ONNX File** (`.onnx`): An ONNX model used as input for NPU command generation.  
- **Config File** (`.json`): A JSON configuration file that includes parameters such as quantization methods, image processing settings, and other options. Refer to **[JSON File Configuration](02_05_JSON_File_Configuration.md)**.  

**Makefile** (Executable File distribution)  
Build script for compiling the sample model. Used with the CLI execution method. Refer to [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface) for usage details.  

---
