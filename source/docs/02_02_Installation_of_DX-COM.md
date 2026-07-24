This section provides instructions for installing **DX-COM** on supported Linux distributions and using it through both the `dxcom` command-line interface and the `dx_com` Python module.  

!!! note "Distribution Update"
    The standalone executable distribution is deprecated. This manual describes the wheel-based workflow only.

---

## Pre-Installation Requirements

Before installing **DX-COM**, ensure the following libraries are installed.

- OpenGL runtime support for graphical operations
    - Debian/Ubuntu: `libgl1-mesa-glx`
    - Fedora/RHEL/CentOS: `mesa-libGL`
- Core utility library used by many GNOME and GTK applications
    - Debian/Ubuntu: `libglib2.0-0`
    - Fedora/RHEL/CentOS: `glib2`
- GNU `make`

Run the command that matches your distribution to install the required libraries.

**Debian / Ubuntu**
```bash
sudo apt-get install -y --no-install-recommends libgl1-mesa-glx libglib2.0-0 make
```

**Fedora**
```bash
sudo dnf install -y mesa-libGL glib2 make
```

**RHEL / CentOS (9, 10)**

`mesa-libGL` lives in the CodeReady Builder (CRB) repository on RHEL/CentOS, so enable it first:
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled crb        # RHEL/CentOS 9, 10
sudo dnf install -y mesa-libGL glib2 make
```

---

## Installation

**Supported Environments**  

| **Python Version** |
| :--- |
| Python 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14 |

**Install the Wheel**  

DX-COM wheels are built with `auditwheel` and tagged with the `manylinux_2_31_x86_64` platform tag, which means they require **glibc ≥ 2.31** on the host (Ubuntu 20.04+, Debian 11+, RHEL/CentOS 9+, Fedora 42+).

Download the wheel file matching your Python version and install it using pip:  

```bash
pip install dx_com-<VERSION>-<PYTAG>-<ABITAG>-manylinux_2_31_x86_64.whl
```

For example, for Python 3.11:  

```bash
pip install dx_com-<VERSION>-cp311-cp311-manylinux_2_31_x86_64.whl
```

!!! note "Wheel filename format"
    The wheel filename follows PEP 425 / PEP 600 conventions: `dx_com-<VERSION>-<PYTAG>-<ABITAG>-<PLATFORMTAG>.whl`. For DX-COM v2.4.0 on CPython 3.12, this looks like `dx_com-2.4.0-cp312-cp312-manylinux_2_31_x86_64.whl`.

**Verify the Installation**

```bash
dxcom --version
python3 -c "import dx_com; print(dx_com.__version__)"
```

For detailed information on command-line usage, refer to the [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface) guide. For the `dx_com` Python module, including the `compile()` function signature, parameters, and examples, refer to the [Python Wheel Package Usage](02_06_Execution_of_DX-COM.md#python-wheel-package-usage) section in the Execution guide.

---
