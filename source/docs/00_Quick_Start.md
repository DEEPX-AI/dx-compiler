# Quick Start Guide

Welcome to **DX-COM** (DEEPX Compiler)! This guide will help you compile your first ONNX model in just a few minutes.

---

## Install DX-COM

Follow [Installation of DX-COM](02_02_Installation_of_DX-COM.md) to install and verify DX-COM before continuing with this quick start.

---

## Compile Sample Models

When DX-COM is installed from the package bundle, sample models and calibration data are automatically downloaded to `dx_com/` during `install.sh`. If they are not available, run the helper scripts below first:

```bash
./example/1-download_sample_models.sh
./example/2-download_sample_calibration_dataset.sh
```

These helper scripts populate the sample asset directories used by the bundle, such as `dx_com/sample_models/` and `dx_com/calibration_dataset/`.

Then run all sample compilations at once:

```bash
./example/3-compile_sample_models.sh
```

---

## Compile Your Own Model

### With the `dxcom` Command

For complete examples and options, see [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface).

```bash
dxcom -m model.onnx -c config.json -o output/
```

### With the `dx_com` Python Module

For complete examples and options, see [dx_com Python Module Usage](02_06_Execution_of_DX-COM.md#python-wheel-package-usage).

**Using `dx_com.compile()`:**
```python
import dx_com
dx_com.compile(model="model.onnx", output_dir="output/", config="config.json")
```

## Next Steps

1. **Installation of DX-COM** → [Installation of DX-COM](02_02_Installation_of_DX-COM.md)  
2. **Execution of DX-COM** → [Execution of DX-COM](02_06_Execution_of_DX-COM.md)  
3. **JSON File Configuration** → [JSON File Configuration](02_05_JSON_File_Configuration.md)  
4. **Common Use Cases** → [Common Use Cases](02_08_Common_Use_Cases.md)  

---

Happy compiling!
