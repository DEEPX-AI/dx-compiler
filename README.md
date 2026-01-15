# DEEPX DX-Compiler

## DXNN® - DEEPX NPU SDK (DX-AS: DEEPX All-Suite)

**DX-AS (DEEPX All-Suite)** is an integrated environment of frameworks and tools that enables inference and compilation of AI models using DEEPX devices. Users can build the integrated environment by installing individual tools, but DX-AS maintains optimal compatibility by aligning the versions of the individual tools.

![](./source/img/deepx_dxnn_sdk_simple.png)
![](./source/img/dxnn-workflow.png)

---

## [AI Model Compile Environment](https://github.com/DEEPX-AI/dx-compiler) (Compiler Platform)

**Purpose**  
  - Must be installed on the Host machine that will perform the compilation (converting) of ONNX models to our proprietary DXNN (DEEPX format).  

**Core Components**
  - DX-COM: Converts ONNX models into highly optimized, NPU-ready binaries.

**Flexibility & Support**
  - OS: Compatible with Debian-based Linux (Ubuntu 20.04, 22.04, 24.04)
  - Architecture: Supports x86_64 only

**Easy Installation**
  - Our single script automates the full setup process
  - All DX-Compiler components are ready to use upon completion.

---

## Quick Guide (Install and Run)

DX-Compiler provides scripts for local installation, as well as scripts for building Docker images and running containers.

### Local Installation
DX-Compiler supports installation in local environments. You can install DX-Compiler by following the instructions at this [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/staging/docs/source/installation.md#local-installation).

### Docker Installation
DX-Compiler support installation in docker envirionments.
You can install DX-Compiler by following the instructions at this [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/staging/docs/source/installation.md#build-the-docker-image)


### Run
For detailed instructions on how to run DX-Compiler, please refer to the link below. [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/installation.md#run-dx-compiler)

---

## Create User Manual

### Install Python Dependencies

To install the necessary Python packages, run the following command:

```bash
pip install mkdocs mkdocs-material mkdocs-video pymdown-extensions mkdocs-to-pdf 
```

### Generate Documentation (HTML and PDF)

To generate the user guide as both HTML and PDF files, execute the following command:

```bash
mkdocs build
```

This will create:
- **HTML documentation** in the `docs/` folder - open `docs/index.html` in your web browser
- **PDF file**: `DEEPX_DX-COM_UM_[version]_[release_date].pdf` in the root directory
