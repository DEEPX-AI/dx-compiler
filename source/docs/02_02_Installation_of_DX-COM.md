This section provides instructions for installing **DX-COM** on supported Ubuntu distributions. **DX-COM** is available in two distribution formats:  

- **Executable File**: Command-line based compilation via the `dx_com` executable  
- **Python Wheel Package**: Programmatic compilation using the `dx_com` Python module  

Choose the installation method that best suits your workflow.  

---

## Pre-Installation Requirements

Before installing **DX-COM** (regardless of the method), ensure the following libraries are installed.  

- `libgl1-mesa-glx`: Provides OpenGL runtime support for graphical operations  
- `libglib2.0-0`: Core utility library used by many GNOME and GTK applications  

Run the following command to install the required libraries.  
```
sudo apt-get install -y --no-install-recommends libgl1-mesa-glx libglib2.0-0 make
```

---

## Installation Methods

### Option 1: Executable File

**Installation**  

After downloading the compiler file, extract it using the following command:

```bash
tar xfz dx_com_M1_vx.x.x.tar.gz
```

After extraction, the directory `dx_com/` will contain the compiler executables, sample ONNX models, JSON configuration files, and a sample `Makefile` for compilation.

For detailed information on command-line usage, refer to the [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface) guide.

---

### Option 2: Python Wheel Package

**Supported Environments**  

| **Python Version** |
| :--- |
| Python 3.8, 3.9, 3.10, 3.11, 3.12 |

**Installation**  

After downloading the wheel package file, extract it using the following command:

```bash
tar xfz dx_com_M1_vx.x.x_wheel.tar.gz
```

Then install the wheel file matching your Python version using pip:  

```bash
pip install dx_com-2.2.0-cp<VERSION>-cp<VERSION>-linux_x86_64.whl
```

For example, for Python 3.11:  

```bash
pip install dx_com-2.2.0-cp311-cp311-linux_x86_64.whl
```

For detailed information on Python wheel usage, including the `compile()` function signature, parameters, and examples, refer to the [Python Wheel Package Usage](02_06_Execution_of_DX-COM.md#python-wheel-package-usage) section in the Execution guide.

---
