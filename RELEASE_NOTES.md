
# RELEASE_NOTES

## DX-Compiler v2.4.0 / 2026-06-16

-   DX-COM: v2.4.0
-   DX-TRON: v2.0.1 (Deprecated)

----------

> **⚠️ Deprecation Notice — DX-TRON**
>
> Starting with DX-Compiler **v2.4.0**, **DX-TRON is deprecated** and will be removed in a future release. No further feature updates or bug fixes are planned for DX-TRON. We recommend migrating to the new **HTML graph viewer** bundled with DX-COM (see *Standalone HTML Graph Viewer* below) for model inspection and visualization.


> **⚠️ Deprecation Notice — PPU Type 2**
>
> Starting with DX-Compiler **v2.4.0**, the legacy **PPU type 2** post-processing mode (used for YOLOv8-family DFL post-processing) is **deprecated** and will be removed in a future release. Compiling a model that uses PPU type 2 now emits a deprecation warning. Please migrate to the new **`dx_com.pre_optimize()` API** with the built-in YOLO post-processing passes (see *Added* below).

Here are the **DX-Compiler v2.4.0** Release Notes.

### DX-COM (v2.4.0)

### 1. Changed

-   **PPU Type 2 Deprecated**: The legacy PPU type 2 post-processing mode is now deprecated and emits a deprecation warning when used. See the Deprecation Notice above for the migration path.
-   **Faster, Lighter Compilation**: Reduced memory usage and improved compile time, especially on large models.
-   **Expanded Python Version Support**: In addition to Python 3.8–3.12, DX-COM now supports **Python 3.13 and 3.14**.

### 2. Fixed

-   Fixed a Python API issue where models expecting integer inputs were sometimes fed float data, causing accuracy degradation.
-   Fixed several Q-PRO / DXQ quantization crashes and stability issues observed on real models.
-   Fixed multiple compilation errors and runtime issues caused by tiling, partitioning, and memory allocation in models containing `Split`, `Concat`, `Reshape`, `Bilinear Resize`, `Clip`, or odd spatial dimensions.
-   Fixed compatibility issues with **NumPy 2.4+** and **onnxruntime ≥ 1.25.0**.
-   **Reduce ExpandDim Preprocessing In Config For GrayScale**: When converting to GrayScale color, one channel was automatically squeezed, which caused a dimensional difference compared to the RGB image. So additional ExpandDim preprocessing is needed before. Therefore, we resolve this problem and preprocessing config to be identical to that of RGB images.

### 3. Added

-   **Automated Q-PRO Configuration**: Q-PRO quantization (formerly available only by hand-picking DXQ combinations) is now much easier to use. DX-COM can now **automatically generate DXQ combinations** for you and run Q-PRO under the hood, removing the need to manually tune the many DXQ knobs to get higher-accuracy quantization.
-   **Quantization-Aware Training (QAT)**: Added end-to-end **QAT** support directly through `dx_com.compile()`. When the supplied config JSON includes a `qmaster` block, `dx_com.compile()` automatically switches to QAT mode and runs the training pipeline using the same dataset settings as PTQ calibration. Available from both the `dxcom` CLI and the Python API. A new `fast_run` flag is also available for quick QAT smoke tests.
-   **QXNN Resume (Re-quantization without Recompile)**: Added a checkpoint-based **QXNN resume** flow available from both the `dxcom` CLI and the Python API. Once a model has been compiled, users can re-run quantization with different settings (e.g., a different calibration method) without repeating the earlier compile phases, dramatically shortening the iteration loop when tuning quantization quality.
-   **Quantization Diagnosis Report (HTML)**: Added an HTML report that visualizes per-layer quantization quality, highlights problematic layers, and includes ready-to-paste compile snippets to retry compilation with recommended settings. Enabled via the new `quant_diagnosis` option, available from both the `dxcom` CLI and `dx_com.compile()`.
-   **Interactive HTML Graph Viewer (replaces DX-TRON)**: DX-COM now produces a standalone HTML viewer for inspecting compiled models, including parameter shapes, CPU/NPU partition reasons, and cross-subgraph connections. This replaces the DX-TRON workflow (see Deprecation Notice above).
-   **`dx_com.pre_optimize()` API**: Added a new top-level `dx_com.pre_optimize()` API for applying ONNX-level pre-processing transforms before compilation, with built-in support for **YOLO post-processing** integration (detection and segmentation modes). See the [Pre-Optimize API](source/docs/02_09_Pre_Optimize_API.md) chapter of the user manual.
-   **Ubuntu 26.04 Validation**: DX-COM is now validated on **Ubuntu 26.04**, in addition to the previously supported Linux distributions.
-   **DEEPX Agent-Driven Development (`dx-agent-dev`) — Beta**: Compile models with a natural-language prompt. An AI coding agent drives DX-COM to turn ONNX/`.pt` (including Ultralytics `format=deepx`) into a deployable `.dxnn`, with ONNX-vs-DXNN numerical verification. (Beta — behavior may change.)

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function.

### DX-TRON (v2.0.1)

**Deprecated.** DX-TRON is deprecated as of DX-Compiler v2.4.0 and will be removed in a future release. Please migrate to the DX-COM standalone HTML graph viewer for model visualization. No changes in this release.

----------

## DX-Compiler v2.3.1 / 2026-05-06

-   DX-COM: v2.3.0
-   DX-TRON: v2.0.1

----------

Here are the **DX-Compiler v2.3.1** Release Notes.

### Installer

### 1. Fixed

-   Fixed `uninstall.sh` not removing installed packages and extracted module directories.
    -   `dx_com` Python package is now properly uninstalled via `pip3 uninstall` before the virtual environment is removed.
    -   `dxtron` Debian package is now properly removed via `apt-get remove`.
    -   `dx_com/` and `dx_tron/` directories are now deleted on uninstall.

### 2. Added

-   Added `--target=<dx_com|dx_tron|all>` option to `uninstall.sh` (default: `all`), consistent with `install.sh`.

----------

## DX-Compiler v2.3.0 / 2026-03-30

-   DX-COM: v2.3.0
-   DX-TRON: v2.0.1

----------

Here are the **DX-Compiler v2.3.0** Release Notes.

### DX-COM (v2.3.0)

### 1. Changed

-   Relaxed Python package dependency constraints to improve installation flexibility.
-   Reduced NPU inference latency for most models.
-   Improved compiler performance to reduce compilation time.

### 2. Fixed

-   Fixed various DX-COM compiler stability issues.

### 3. Added

-   **TopK-Optimized Post-Processing Pipeline**: Added an optimized post-processing pipeline for supported DFL-based YOLO models that applies TopK filtering before bounding box decoding, reducing CPU post-processing workload and improving runtime efficiency.
-   **Batched Convolution Support**: Added support for batched convolution.
-   **Expanded Linux Distribution Validation**: In addition to previously supported Ubuntu 20.04, 22.04, and 24.04, DX-COM was verified on Fedora 42-45, Red Hat 9-10, and CentOS Stream 9-10 in this release.

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function. This will be resolved in an upcoming release.
-   The following models from [DX ModelZoo](https://developer.deepx.ai/modelzoo/) show high accuracy variability depending on the host CPU and calibration dataset used: OSNet0_5, RepVGGA2, YoloV9C, DnCNN series.

### DX-TRON (v2.0.1)

No changes in this release.

----------

## DX-Compiler v2.2.1 / 2026-02-11

-   DX-COM: v2.2.1
-   DX-TRON: v2.0.1

----------

Here are the **DX-Compiler v2.2.1** Release Notes.

### DX-COM (v2.2.1)

### 1. Changed

-   None

### 2. Fixed

-   Fixed DXQ enhanced quantization option bugs.
-   Fixed PPU compilation bug in Python Wheel Package for Python 3.8, 3.9, and 3.10.
-   Fixed an issue where compilation proceeded without error when invalid model input names were specified.

### 3. Added

-   **GPU Quantization (JSON Config)**: Added `quantization_device` support in JSON configuration file, enabling GPU-accelerated quantization via CLI (`dxcom`) in addition to the Python API. Available only with the Python wheel package installation.
-   **GPU Auto-Detection**: When `quantization_device` is not specified, DX-COM now automatically uses GPU if a CUDA-compatible GPU is available, otherwise falls back to CPU.

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function.

### DX-TRON (v2.0.1)

No changes in this release.

----------

## DX-Compiler v2.2.0 / 2025-12-24

-   DX-COM: v2.2.0
-   DX-TRON: v2.0.1

----------

Here are the **DX-Compiler v2.2.0** Release Notes.

### DX-COM (v2.2.0)

### 1. Changed

-   None

### 2. Fixed

-   Resolved accuracy degradation issue in the `DeepLabV3PlusMobilenet-1` model from DX ModelZoo.

### 3. Added

-   **New Installation Option: Python Wheel Package**
    - Install DX-COM via `pip` for Python projects (Python 3.8, 3.9, 3.10, 3.11, 3.12)
    - Use `dx_com.compile()` API directly in your Python code
    - No JSON configuration file needed (optional) - use torch DataLoader instead
    - Perfect for: automated workflows, Jupyter notebooks, integration with existing ML pipelines
    
-   **Multi-Input Model Support** (via Python API)
    - Compile models with multiple inputs (e.g., stereo vision, dual-stream models)
    - Use torch DataLoader to provide data for each input independently
    
-   **Extended PPU Support**
    - YOLOv8, YOLOv9, YOLOv10, YOLOv11, YOLOv12 now compatible with hardware-accelerated post-processing
    - In addition to previously supported YOLOv3, YOLOv4, YOLOv5, YOLOv7

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function.

### DX-TRON (v2.0.1)

### 1. Changed

-   None

### 2. Fixed

-   None

### 3. Added

-   **New Installation Method: Debian Package (DEB)**
    - Install via `.deb` package on Ubuntu 20.04, 22.04, and 24.04 (supports amd64, arm64)
    
-   **Local Web Server Support**: Run DX-TRON locally to view compiled models in your browser.
    
-   Added support for Ubuntu 24.04.

----------

## DX-Compiler v2.1.0 / 2025-11-24

-   DX-COM: v2.1.0    
   
-   DX-TRON: v2.0.0
    
----------

Here are the **DX-Compiler v2.1.0** Release Notes.

### DX-COM (v2.1.0)

### 1. Changed

-   Removed deprecated command-line options: `--jobs`, `--shrink`, `--info` (or `-i`).
    
-   Clarified ONNX opset version support: versions 11-21 are supported (version 22 and above are not supported).
    
-   Removed restrictions on `Split`, `Transpose`, `Reshape`, `Flatten`, and `Slice` operators.
    

### 2. Fixed

-   None
    

### 3. Added

-   Added new command-line options:
    
    -   `--aggressive_partitioning`: Enables aggressive partitioning to maximize operations executed on NPU.
        
    -   `--opt_level {0,1}`: Controls optimization level (default: 1).
        
    -   `--compile_input_nodes` / `--compile_output_nodes`: Support for Partial Compilation.
        
-   Added support for `Gather` operator.

-   Reintroduced the DXQ enhanced quantization option (`enhanced_scheme`, DXQ-P0 to DXQ-P5), previously removed in DX-COM v2.0.0.
    
-   Reinstated PPU (Post-Processing Unit) support.
    
    -   Supported models: YOLOv3, YOLOv4, YOLOv5, YOLOv7 (anchor-based), YOLOX (anchor-free).
    

### 4. Known Issues

-   Accuracy degradation has been observed in the `DeepLabV3PlusMobilenet-1` model from DX ModelZoo.
    

----------

## DX-Compiler v2.0.0 / 2025-08-11

-   DX-COM: v2.0.0
    
-   DX-TRON: v2.0.0
    

----------

Here are the **DX-Compiler v2.0.0** Release Note for each module.

### DX-COM (v2.0.0)

### 1. Changed

-   Compatibility with DX-RT versions earlier than v3.0.0 is not guaranteed.
    
-   Removed the DXQ enhanced quantization option (`enhanced_scheme`) in DX-COM v2.0.0 (reintroduced in DX-COM v2.1.0).
    
-   `PPU(Post-Processing Unit)` is no longer supported, and there are no current plans to reinstate it.
    

### 2. Fixed

-   None
    

### 3. Added

-   Re-enabled support for the following operators:
    
    -   `Softmax`
        
    -   `Slice`
        
-   Newly added support for the `ConvTranspose` operator.
    
-   Partial support for Vision Transformer (ViT) models:
    
    -   Verified with the following OpenCLIP models:
        
        -   ViT-L-14, ViT-L-14-336, ViT-L-14-quickgelu
            
        -   RN50x64, RN50x16
            
        -   ViT-B-16, ViT-B-32-256, ViT-B-16-quickgelu
            

### DX-TRON (v2.0.0)

### 1. Changed

-   None
    

### 2. Fixed

-   None
    

### 3. Added

-   `DX-TRON` can now run on Linux amd64 environments and can be installed via dx-all-suite.
    

----------

## DX-Compiler v1.0.0 Initial Release / 2025-07-23

-   DX-COM : v1.60.1
    
-   DX-TRON : v0.0.8
    

We're excited to announce the **initial release of DX-Compiler v1.0.0!**

DX-COM is a core component of the DEEPX SDK, designed to streamline your AI development workflow by efficiently converting pre-trained ONNX models into highly optimized `.dxnn` binaries for DEEPX NPUs. This initial release marks a significant step towards enabling low-latency and high-efficiency inference on DEEPX NPU hardware.

----------

### What's New?

This v1.0.0 release introduces the foundational capabilities of DX-COM:

-   **ONNX to** `.dxnn` **Conversion:** Seamlessly transforms your pre-trained ONNX models into a hardware-optimized `.dxnn` binary format.
    
-   **JSON Configuration Support:** Utilizes an associated JSON file to define crucial pre/post-processing settings and compilation parameters, giving you fine-grained control over the optimization process.
    
-   **Optimized for DEEPX NPU:** Generates `.dxnn` files specifically tailored for low-latency and high-efficiency inference on DEEPX Neural Processing Units.
    
-   **Includes** `dx_com` **module (v1.60.1):** This version of DX-Compiler bundles the `dx_com` module, providing the core compilation functionalities.
    
-   `dx_tron` **module (v0.0.8) available:** The `dx_tron` module is also part of DX-Compiler. While its official inclusion in the main release is planned for an upcoming version, you can download `dx_tron` (v0.0.8) today from [developer.deepx.ai](https://developer.deepx.ai/ "https://developer.deepx.ai/").
    

----------

### Key Role in the DEEPX SDK

DX-COM plays a pivotal role within the broader DEEPX SDK ecosystem, interacting closely with other components to provide a complete AI development toolchain:

-   **Complements DX-RT:** The compiled `.dxnn` files are directly consumable by **DX-RT (Runtime)** for execution on DEEPX NPU hardware.
    
-   **Integrates with DX ModelZoo:** Models from **DX ModelZoo** can be compiled using DX-COM for optimized performance on DEEPX NPUs.
    

----------

We believe DX-Compiler v1.0.0 will be an indispensable tool for developers looking to deploy high-performance AI applications on DEEPX NPUs with minimal effort.

----------

### DX-COM (v1.60.1)

### 1. Changed

-   None
    

### 2. Fixed

-   None
    

### 3. Added

-   Initial version release of DX-Compiler. This core component of the DEEPX SDK now includes the dx_com module (version 1.60.1). It is designed to streamline AI development by efficiently converting pre-trained ONNX models into highly optimized .dxnn binaries for DEEPX NPUs, enabling low-latency and high-efficiency inference.
    

### DX-TRON (v0.0.8)

-   The dx_tron module (v0.0.8) is currently available for download at [developer.deepx.ai](http://developer.deepx.ai/ "http://developer.deepx.ai"). This module is part of the DX-Compiler, and its official inclusion in the main release will be in an upcoming version.
