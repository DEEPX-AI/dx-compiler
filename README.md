# DeepX Compiler(dx-compiler)

## Quick Guide (Install and Run)

dx-compiler provides scripts for local installation, as well as scripts for building Docker images and running containers.

### Local Installation

dx-compiler supports installation in local environments. You can install dx-compiler by following the instructions at this [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/staging/docs/source/installation.md#local-installation).


### Docker Installation

dx-compiler support installation in docker envirionments.
You can install dx-compiler by following the instructions at this [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/staging/docs/source/installation.md#build-the-docker-image)


### Run

For detailed instructions on how to run dx-compiler, please refer to the link below. [LINK](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/installation.md#run-dx-compiler)


## Create User Manual

### Install Python Dependencies

To install the necessary Python packages, run the following command:

```bash
pip install mkdocs mkdocs-material mkdocs-video pymdown-extensions mkdocs-with-pdf 
```

### Generate Documentation (HTML and PDF)

To generate the user guide as both HTML and PDF files, execute the following command:

```bash
mkdocs build
```

This will create:
- **HTML documentation** in the `docs/` folder - open `docs/index.html` in your web browser
- **PDF file**: `DEEPX_DX-COM_UM_v2.1.0_2025_11.pdf` in the root directory
