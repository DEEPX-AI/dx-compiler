This section provides instructions for installing **DX-COM** on supported Linux distributions and using it through both the `dxcom` command-line interface and the `dx_com` Python module.  

!!! note "Distribution Update"
    The standalone executable distribution is deprecated. This manual describes the wheel-based workflow only.

---

## Pre-Installation Requirements

Before installing **DX-COM**, ensure the following libraries are installed.  

- `libgl1-mesa-glx`: Provides OpenGL runtime support for graphical operations  
- `libglib2.0-0`: Core utility library used by many GNOME and GTK applications  

Run the following command to install the required libraries.  
```
sudo apt-get install -y --no-install-recommends libgl1-mesa-glx libglib2.0-0 make
```

---

## Installation

**Supported Environments**  

| **Python Version** |
| :--- |
| Python 3.8, 3.9, 3.10, 3.11, 3.12 |

**Install the Wheel**  

Download the wheel file matching your Python version and install it using pip:  

```bash
pip install dx_com-<VERSION>-cp<VERSION>-cp<VERSION>-linux_x86_64.whl
```

For example, for Python 3.11:  

```bash
pip install dx_com-<VERSION>-cp311-cp311-linux_x86_64.whl
```

**Verify the Installation**

```bash
dxcom --version
python3 -c "import dx_com; print(dx_com.__version__)"
```

For detailed information on command-line usage, refer to the [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface) guide. For the `dx_com` Python module, including the `compile()` function signature, parameters, and examples, refer to the [Python Wheel Package Usage](02_06_Execution_of_DX-COM.md#python-wheel-package-usage) section in the Execution guide.

---
