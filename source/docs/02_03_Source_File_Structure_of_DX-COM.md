After running `install.sh`, the prepared `dx_com/` directory is organized as follows.  

```
dx_com/
├── sample_models/            # Sample model assets
│  ├── onnx/                  # Sample ONNX models
│  └── json/                  # Sample JSON files
├── calibration_dataset/      # Sample calibration dataset
└── output/                   # Compiled .dxnn files (created by 3-compile_sample_models.sh)
```

**dx_com/**  
This directory stores the sample assets prepared during `install.sh`. The `dxcom` command-line interface and the `dx_com` Python module are installed into the virtual environment by `install.sh`; refer to [Installation of DX-COM](02_02_Installation_of_DX-COM.md) for installation instructions.  

**sample_models**  
This directory contains the downloaded sample ONNX models and JSON configuration files used by the sample compilation workflow.  

- **ONNX Files** (`dx_com/sample_models/onnx/`): Sample ONNX models used as compiler inputs  
- **JSON Files** (`dx_com/sample_models/json/`): Sample configuration files used with the sample models. Refer to **[JSON File Configuration](02_05_JSON_File_Configuration.md)**.  

---
