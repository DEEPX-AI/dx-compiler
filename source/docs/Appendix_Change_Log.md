
## v2.4.0 (2026-06-16)

DX-Compiler Version

-   DX-COM: v2.4.0
-   DX-TRON: v2.0.1 (Deprecated)

!!! warning "Deprecation Notice — DX-TRON"
    Starting with DX-Compiler **v2.4.0**, **DX-TRON is deprecated** and will be removed in a future release. No further feature updates or bug fixes are planned for DX-TRON. We recommend migrating to the new **HTML graph viewer** bundled with DX-COM (see *Interactive HTML Graph Viewer* below) for model inspection and visualization.

!!! warning "Deprecation Notice — PPU Type 2"
    Starting with DX-Compiler **v2.4.0**, the legacy **PPU type 2** post-processing mode (used for YOLOv8-family DFL post-processing) is **deprecated** and will be removed in a future release. Compiling a model that uses PPU type 2 now emits a deprecation warning. Please migrate to the new **`dx_com.pre_optimize()` API** with the built-in YOLO post-processing passes (see *Added* below).

#### Changed

-   **PPU Type 2 Deprecated**: The legacy PPU type 2 post-processing mode is now deprecated and emits a deprecation warning when used. See the Deprecation Notice above for the migration path.
-   **Faster, Lighter Compilation**: Reduced memory usage and improved compile time, especially on large models.
-   **Expanded Python Version Support**: In addition to Python 3.8–3.12, DX-COM now supports **Python 3.13 and 3.14**.

#### Fixed

-   Fixed a Python API issue where models expecting integer inputs were sometimes fed float data, causing accuracy degradation.
-   Fixed several Q-PRO / DXQ quantization crashes and stability issues observed on real models.
-   Fixed multiple compilation errors and runtime issues caused by tiling, partitioning, and memory allocation in models containing `Split`, `Concat`, `Reshape`, `Bilinear Resize`, `Clip`, or odd spatial dimensions.
-   Fixed compatibility issues with **NumPy 2.4+** and **onnxruntime ≥ 1.25.0**.

#### Added

-   **Automated Q-PRO Configuration**: Q-PRO quantization (formerly available only by hand-picking DXQ combinations) is now much easier to use. DX-COM can now **automatically generate DXQ combinations** for you and run Q-PRO under the hood, removing the need to manually tune the many DXQ knobs to get higher-accuracy quantization.
-   **Quantization-Aware Training (QAT)**: Added end-to-end **QAT** support directly through `dx_com.compile()`. When the supplied config JSON includes a `qmaster` block, `dx_com.compile()` automatically switches to QAT mode and runs the training pipeline using the same dataset settings as PTQ calibration. Available from both the `dxcom` CLI and the Python API. A new `fast_run` flag is also available for quick QAT smoke tests. See [Quantization-Aware Training (QAT)](02_08_Quantization_Aware_Training.md).
-   **QXNN Resume (Re-quantization without Recompile)**: Added a checkpoint-based **QXNN resume** flow available from both the `dxcom` CLI and the Python API. Once a model has been compiled, users can re-run quantization with different settings (e.g., a different calibration method) without repeating the earlier compile phases, dramatically shortening the iteration loop when tuning quantization quality.
-   **Quantization Diagnosis Report (HTML)**: Added an HTML report that visualizes per-region quantization quality, flags high-severity regions, and includes ready-to-paste compile snippets to retry compilation with recommended settings. Enabled via the new `quant_diagnosis` option, available from both the `dxcom` CLI and `dx_com.compile()`.
-   **Interactive HTML Graph Viewer (replaces DX-TRON)**: DX-COM now produces a standalone HTML viewer for inspecting compiled models, including parameter shapes, CPU/NPU partition reasons, and cross-subgraph connections. This replaces the DX-TRON workflow (see Deprecation Notice above).
-   **`dx_com.pre_optimize()` API**: Added a new top-level `dx_com.pre_optimize()` API for applying ONNX-level pre-processing transforms before compilation, with built-in support for **YOLO post-processing** integration (detection and segmentation modes). See the [Pre-Optimize API](02_09_Pre_Optimize_API.md) chapter.
-   **Ubuntu 26.04 Validation**: DX-COM is now validated on **Ubuntu 26.04**, in addition to the previously supported Linux distributions.

#### Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function.

---

## v2.3.1 (May 2026)

DX-Compiler Version

-   DX-COM: v2.3.0
-   DX-TRON: v2.0.1

#### Fixed

-   Fixed `uninstall.sh` not removing installed packages and extracted module directories.
    -   `dx_com` Python package is now properly uninstalled via `pip3 uninstall` before the virtual environment is removed.
    -   `dxtron` Debian package is now properly removed via `apt-get remove`.
    -   `dx_com/` and `dx_tron/` directories are now deleted on uninstall.

#### Added

-   Added `--target=<dx_com|dx_tron|all>` option to `uninstall.sh` (default: `all`), consistent with `install.sh`.

---

## v2.3.0 (March 2026)

DX-Compiler Version

- dx_com : 2.3.0  
- dx_tron : 2.0.1

#### Changed

- **Python Packaging**: Relaxed Python package dependency constraints to improve installation flexibility.
- **Distribution**: The standalone DX-COM executable distribution is deprecated. The user manual now documents the wheel-based workflow only.
- **Performance**:

    - Reduced NPU inference latency for most models.
    - Improved compiler performance to reduce compilation time.

#### Fixed

- **Compiler Stability**: Fixed various DX-COM compiler stability issues.

#### Added

- **TopK-Optimized Post-Processing Pipeline**: Added an optimized post-processing pipeline for supported DFL-based YOLO models that applies TopK filtering before bounding box decoding, reducing CPU post-processing workload and improving runtime efficiency.
- **Batched Convolution Support**: Added support for batched convolution.
- **Linux Distribution Validation**: In addition to Ubuntu 20.04, 22.04, and 24.04, DX-COM v2.3.0 was also validated on Fedora 42-45, Red Hat 9-10, and CentOS Stream 9-10.

---

## v2.2.1 (February 2026)

DX-Compiler Version

- dx_com : 2.2.1  
- dx_tron : 2.0.1

#### Changed

- None

#### Fixed

- **DXQ Quantization**: Fixed DXQ enhanced quantization option bugs.
- **Python Wheel Package**: Fixed PPU compilation bug for Python 3.8, 3.9, and 3.10.
- **Input Validation**: Fixed an issue where compilation proceeded without error when invalid model input names were specified.

#### Added

- **GPU Quantization (JSON Config)**: Added `quantization_device` support in JSON configuration file, enabling GPU-accelerated quantization via CLI (`dxcom`) in addition to the `dx_com` Python module. Available only with the Python wheel package installation.
- **GPU Auto-Detection**: When `quantization_device` is not specified, DX-COM now automatically uses GPU if a CUDA-compatible GPU is available, otherwise falls back to CPU.

---

## v2.2.0 (December 2025)

DX-Compiler Version

- dx_com : 2.2.0  
- dx_tron : 2.0.1

#### Changed

- None

#### Fixed

- **Model Accuracy**: Resolved accuracy degradation issue in the `DeepLabV3PlusMobilenet-1` model from DX ModelZoo.

#### Added

- **PPU Support**: Extended PPU support to YOLOv8, YOLOv9, YOLOv10, YOLOv11, and YOLOv12.
- **Python Wheel Package**: DX-COM is now available as a Python wheel package (in addition to the existing executable file), supporting Python 3.8, 3.9, 3.10, 3.11, and 3.12, enabling programmatic compilation using torch DataLoader without configuration files.
- **Multi-Input Model Support**: Added support for multi-input models through torch DataLoader in the Python wheel package.
- **DX-TRON**:
    - Debian package (.deb) installation support
    - Local web browser hosting (`dxtron` command)
    - Ubuntu 24.04 support

---

## v2.1.0 (November 2025)

DX-Compiler Version

- dx_com : 2.1.0  
- dx_tron : 2.0.0  

#### Changed

- **Command-Line Interface**: Removed deprecated command-line options: `--jobs`, `--shrink`, `--info` (or `-i`).

- **ONNX Support**:
    - Removed restrictions on `Split`, `Transpose`, `Reshape`, `Flatten`, and `Slice` operators.
    - Clarified ONNX opset version support (versions 11-21 are supported; version 22 and above are not supported).

#### Added

- **Command-Line Interface**:
    - `--aggressive_partitioning`: Enables aggressive partitioning to maximize operations executed on NPU.
    - `--opt_level {0,1}`: Controls optimization level (default: 1).
    - `--compile_input_nodes` and `--compile_output_nodes`: Support for partial compilation.

- **ONNX Support**: Added support for `Gather` operator.

- **Quantization**: Reintroduced the DXQ enhanced quantization option (`enhanced_scheme`, DXQ-P0 to DXQ-P5), previously removed in dx_com v2.0.0.

- **PPU (Post-Processing Unit)**: Reinstated PPU support.
    - Supported models: YOLOv3, YOLOv4, YOLOv5, YOLOv7 (anchor-based), YOLOX (anchor-free).

---

## v2.0.0 (September 2025)

**ONNX Support**

- Re-enabled support for the following operators:
    - `Softmax`
    - `Slice`

- Newly added support for the following operator:
    - `ConvTranspose`

**Model Support**

- Partial support for Vision Transformer (ViT) models

- Verified with the following [OpenCLIP](https://github.com/mlfoundations/open_clip) models:
    - ViT-L-14, ViT-L-14-336, ViT-L-14-quickgelu
    - RN50x64, RN50x16
    - ViT-B-16, ViT-B-32-256, ViT-B-16-quickgelu

**Compatibility and Deprecations**

- Compatibility with DX-RT versions earlier than v3.0.0 is not guaranteed
- The DXQ enhanced quantization option (`enhanced_scheme`) was removed in dx_com v2.0.0 and reintroduced in dx_com v2.1.0
- `PPU (Post-Processing Unit)` is no longer supported, and there are no current plans to reinstate it

---

## v1.60.1 (June 2025)

**Bug Fixes**

- Internal bug fixes

**Command-Line Interface Updates**

- Added support for:
    - `-v` option: Displays **DX-COM module version**  
    - `-i` option: Displays **internal module information**  
    → For usage, see: [CLI Execution](02_06_Execution_of_DX-COM.md#cli-execution-command-line-interface)  

**ONNX Support**

- The following operators were deprecated and are scheduled to be re-supported in a future release:
    - `Softmax`  
    - `Slice`  

---
