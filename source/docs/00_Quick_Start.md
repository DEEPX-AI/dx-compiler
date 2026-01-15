# Quick Start Guide

Welcome to **DX-COM** (DEEPX Compiler)! This guide will help you compile your first ONNX model in just a few minutes.

---

## Choose Your Installation Method

**What did you download?**

- **Executable File** (`dx_com_M1_vx.x.x.tar.gz`) → See [Installation of DX-COM (Executable File)](02_02_Installation_of_DX-COM.md#option-1-executable-file)
- **Python Wheel** (`dx_com_M1_vx.x.x_wheel.tar.gz`) → See [Installation of DX-COM (Python Wheel)](02_02_Installation_of_DX-COM.md#option-2-python-wheel-package)

Not sure which to choose? See [Installation of DX-COM](02_02_Installation_of_DX-COM.md) for details.

---

## Verify Installation

**Executable File:**
```bash
./dx_com/dx_com --version
```

**Python Wheel:**
```bash
python3 -c "import dx_com; print(dx_com.__version__)"
```

---

## Compile Your First Model

### With Executable File (CLI)

For complete examples and options, see [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface).

```bash
./dx_com/dx_com -m model.onnx -c config.json -o output/
```

### With Python Wheel

For complete examples and options, see [Python API](02_06_Execution_of_DX-COM.md#python-wheel-package-usage).

**Using Python API:**
```python
import dx_com
dx_com.compile(model="model.onnx", output_dir="output/", config="config.json")
```

**Using CLI Command:**
```bash
dxcom -m model.onnx -c config.json -o output/
```

---

## Next Steps

1. **Installation of DX-COM** → [Installation of DX-COM](02_02_Installation_of_DX-COM.md)  
2. **Execution of DX-COM** → [Execution of DX-COM](02_06_Execution_of_DX-COM.md)  
3. **JSON File Configuration** → [JSON File Configuration](02_05_JSON_File_Configuration.md)  
4. **Common Use Cases** → [Common Use Cases](02_07_Common_Use_Cases.md)  

---

Happy compiling!
