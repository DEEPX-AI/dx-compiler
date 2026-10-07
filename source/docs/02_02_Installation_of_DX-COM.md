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

**Option 1: Install from PyPI (Recommended)**

Install the latest version directly from PyPI:

```bash
pip install dx-com
```

**Option 2: Install from Downloaded Wheel**

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

**Option 3: Install with uv (Fastest)**

[uv](https://docs.astral.sh/uv/) resolves and installs dependencies substantially faster than pip. `install.sh` uses uv automatically when it is already installed, so no flag is needed:

```bash
./install.sh --target=dx_com
```

If uv is not installed, `install.sh` uses pip and says so. Pass `--uv=true` to have it install uv first, or `--uv=false` to force the pip path:

```bash
./install.sh --target=dx_com --uv=true
./install.sh --target=dx_com --uv=false
```

To use uv directly against an existing virtual environment:

```bash
uv pip install dx-com
```

!!! note "uv and pip coexist"
    When uv is used, `install.sh` creates the virtual environment with `uv venv --seed`, so `pip` remains available inside it. `--uv=false` keeps the original pip-only path unchanged. uv is only downloaded when you pass `--uv=true`; a plain `./install.sh` on a machine without uv behaves exactly as it did before, using pip.

!!! warning "Archive mode still uses pip"
    `--archive_mode=y` downloads wheels with `pip download`; uv has no equivalent command, so archive mode is unaffected by `--uv`.

---

**Verify the Installation**

```bash
dxcom --version
python3 -c "import dx_com; print(dx_com.__version__)"
```

For detailed information on command-line usage, refer to the **CLI Execution** section in [Execution of DX-COM](02_06_Execution_of_DX-COM.md). For the `dx_com` Python module, including the `compile()` function signature, parameters, and examples, refer to the **Python Wheel Package Usage** section in [Execution of DX-COM](02_06_Execution_of_DX-COM.md).

---
