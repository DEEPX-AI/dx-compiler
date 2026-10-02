# DEEPX DX-Compiler

## DXNN® - DEEPX NPU SDK (DX-AS: DEEPX All-Suite)

**DX-AS (DEEPX All-Suite)** is an integrated environment of frameworks and tools that enables inference and compilation of AI models using DEEPX devices. Users can build the integrated environment by installing individual tools, but DX-AS maintains optimal compatibility by aligning the versions of the individual tools.

![](./source/img/dxnn_sdk_illustration.png)
![](./source/img/dxnn_sdk_illustration_simple.png)

---

## [AI Model Compile Environment](https://github.com/DEEPX-AI/dx-compiler) (Compiler Platform)

**Purpose**  
  - Must be installed on the Host machine that will perform the compilation (converting) of ONNX models to our proprietary DXNN (DEEPX format).  

**Core Components**
  - DX-COM: Converts ONNX models into highly optimized, NPU-ready binaries.

**Flexibility & Support**
  - OS: Compatible with Ubuntu 20.04, 22.04, 24.04, 26.04 (Debian-based), Fedora 42-45, Red Hat Enterprise Linux 9-10, and CentOS Stream 9-10
  - Architecture: Supports x86_64 only

**Easy Installation**
  - Our single script automates the full setup process
  - All DX-Compiler components are ready to use upon completion.

---

## Quick Guide (Install and Run)

DX-Compiler provides scripts for local installation, as well as scripts for building Docker images and running containers.

### One-Line Installation
Install the DX-Compiler (`dx-com`) directly from PyPI, without cloning the repository:
```bash
curl -fsSL https://raw.githubusercontent.com/DEEPX-AI/dx-compiler/main/oneline-install.sh | sh
```
This creates a dedicated virtualenv, installs the `dx-com` package and its dependencies into
it, and links that package's `dxcom` command-line launcher onto your `PATH`, so you can run it
without activating anything:
```bash
dxcom --help
```

- `DX_VERSION=X.Y.Z` — pin the `dx-com` release (default: newest on PyPI)
- `DX_INSTALL_DIR=<dir>` — install root (default: `~/deepx`, venv at `~/deepx/venv-dx-compiler`)
- `DX_BIN_DIR=<dir>` — where the `dxcom` launcher is linked (default: `~/.local/bin`)
- `DX_NO_UV=1` — install with pip instead of [uv](https://docs.astral.sh/uv/)
- `UV_PIN=X.Y.Z` — the uv release to bootstrap (pinned by default, so a run never
  pulls an unreviewed version)

Packages are installed with **uv**, which resolves and downloads wheels considerably faster
than pip — worth having when the dependency set includes `torch` and the CUDA runtime. uv is
used if already present, and otherwise fetched as a standalone binary into `~/.local/bin`; it
is never installed through `pip`, because Debian and Ubuntu mark their system Python PEP 668
externally-managed. If uv cannot be obtained, the installer falls back to pip — both paths
install the same packages into the same venv.

For a system-wide install on a shared machine, point both at system paths and run as root:
```bash
curl -fsSL https://raw.githubusercontent.com/DEEPX-AI/dx-compiler/main/oneline-install.sh \
  | sudo DX_INSTALL_DIR=/opt/deepx DX_BIN_DIR=/usr/local/bin sh
```

Requirements: Debian or Ubuntu, Python 3.8–3.14, and the ability to install system packages.
The installer apt-installs `libgl1-mesa-dev` and `libglib2.0-0` — `dx-com` pulls in
`opencv-python`, whose `cv2` extension links against those X/GL libraries and fails to import
without them — so run it as root or with `sudo` available. The Python dependency set includes
`torch` and `onnxruntime`, so a first install downloads several GB.

#### Uninstalling

Remove what the one-liner installed — the virtualenv and the `dxcom` launcher:
```bash
curl -fsSL https://raw.githubusercontent.com/DEEPX-AI/dx-compiler/main/oneline-uninstall.sh | sh
```

Pass the same `DX_INSTALL_DIR` / `DX_BIN_DIR` you installed with, otherwise it looks in the
default location and finds nothing. For the system-wide install shown above:
```bash
curl -fsSL https://raw.githubusercontent.com/DEEPX-AI/dx-compiler/main/oneline-uninstall.sh \
  | sudo DX_INSTALL_DIR=/opt/deepx DX_BIN_DIR=/usr/local/bin sh
```

It removes the `dxcom` launcher only while that launcher still points into the virtualenv
being deleted, so a `dxcom` belonging to another install is never touched. `uv` and the
`libgl1-mesa-dev` / `libglib2.0-0` system packages are deliberately left in place — other
software may depend on them — and are reported at the end so you can remove them yourself.

If you have the repository checked out, `./uninstall.sh` removes a one-line install as well
as a clone-based one, so you do not need to remember which way it was installed.

For the full repository clone instead — needed for the sample data and the Docker route —
see Local Installation and Docker Installation below.

### Local Installation
For detailed instructions on setting up a local environment for DX-Compiler, please refer to this [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/02_Setting_Up_Environment.md).

### Faster Installation with uv

`install.sh` installs Python packages with [uv](https://docs.astral.sh/uv/) when uv is already available, and with pip otherwise. Nothing extra is required:

```bash
./install.sh
```

Pass `--uv=true` to install uv first if it is missing, or `--uv=false` to force the pip path:

```bash
./install.sh --uv=true
./install.sh --uv=false
```

See [Installation of DX-COM](source/docs/02_02_Installation_of_DX-COM.md) for details.

### Docker Installation
For detailed instructions on setting up a Docker environment for DX-Compiler, please refer to this [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/02_Setting_Up_Environment.md)


### Run Your First NPU Model
For detailed instructions on running your first NPU model with DX-Compiler, please refer to the link below. [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/03_Running_Your_First_NPU_Model.md)

---

## Create User Manual

### Install Python Dependencies

To install the necessary Python packages, run the following command:

```bash
pip install "mkdocs<2" mkdocs-material pymdown-extensions mkdocs-with-pdf weasyprint==65.1
```

### Generate Documentation (HTML and PDF)

To generate the user guide as both HTML and PDF files, execute the following command:

```bash
mkdocs build
```

This will create:
- **HTML documentation** in the `docs/` folder - open `docs/index.html` in your web browser
- **PDF file**: `DEEPX_DX-COM_UM_[version]_[release_date].pdf` in the root directory
