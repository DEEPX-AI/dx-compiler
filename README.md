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

### View Documentation in a Web Browser

To preview the documentation as HTML in your web browser, run the following command in this project's root directory:

```bash
mkdocs serve
```
This will start a local web server, usually found at http://localhost:8000, where you can navigate and view your documentation as a website.
