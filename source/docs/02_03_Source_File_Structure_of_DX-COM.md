The source structure of **DX-COM** is organized as follows. 

```
  dx_com 
    ├── calibration_dataset       # Dataset used to optimize model accuracy 
    ├── dx_com 
    │  ├── cv2/                   # Third party shared libraries (e.g., OpenCV) 
    │  ├── google/                # Third party shared libraries (e.g., protobuf) 
    │  ├── numpy/                 # Third party  shared libraries (e.g., NumPy) 
    │  ├── ...                    # Other dependencies 
    │  └── dx_com                 # Core compiler implementation 
    ├── sample 
    │  ├── MobilenetV1.json       # Sample configuration file 
    │  └── MobilenetV1.onnx       # Sample ONNX model
    └── Makefile                  # Build script for compiling the sample model  
```

**calibration_dataset**  
This directory contains the calibration dataset used for compiling the included sample model as an example. It is used to calibrate the model's input range for quantization purposes.  
If the calibration dataset does not reflect the training or field data, it may significantly degrade model accuracy.  

**dx_com**  
This directory contains executable files and shared libraries used to generate NPU command sets from ONNX models. It includes core compiler logic and third-party dependencies such as OpenCV, NumPy, and Protobuf.  

**sample**  
This folder provides example files to demonstrate how to compile an ONNX model using **DX-COM**.  

- **ONNX File** (`.onnx`): An ONNX model used as input for NPU command generation.  
- **Config File** (`.json`): A JSON configuration file that includes parameters such as quantization methods, image processing settings, and other options. Refer to **[Chapter. JSON File Configuration](02_05_JSON_File_Configuration.md)**.  

---
