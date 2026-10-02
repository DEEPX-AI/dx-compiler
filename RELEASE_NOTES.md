# RELEASE_NOTES

## DX-Compiler v2.5.0 / 2026-09-30

-   DX-COM: v2.5.0
-   DX-TRON: Removed

----------

> **Removal Notice — DX-TRON**
>
> **DX-TRON** was deprecated in **DX-Compiler v2.4.0** and is **removed as of v2.5.0**. The `dx_tron` install target, the `dxtron` CLI/desktop AppImage, the web-server variant, and the `run_dxtron_web.sh` / `run_dxtron_appimage.sh` launcher scripts no longer ship with this package. Use the DX-COM **Compilation Summary Report** (`--export_html`) for model inspection and visualization.

Here are the **DX-Compiler v2.5.0** Release Notes.

### DX-COM (v2.5.0)

### 1. Changed

-   **Python Entry Point Signature**: `dx_com.compile()` now accepts keyword arguments (`**kwargs`). Invoke it with keyword arguments as documented in [Execution of DX-COM](source/docs/02_06_Execution_of_DX-COM.md).
-   **QAT Parameters Restructured**: The Python arguments `quantization_mode`, `qat_config`, `qat_skip_training`, and `qat_resume_from_checkpoint` are **replaced by a single `qmaster` argument** that takes a `QMasterConfig` object (import it from `dx_com`). The former `qat_*` arguments are no longer honored from Python code. Triggering QAT from a JSON `qmaster` block is unchanged — QAT is still auto-selected.
-   **`pre_optimize` Pass Renaming (Breaking)**: `yolo_postprocess` → `yolo_dfl_postprocess` and `yolo26_postprocess` → `yolo_no_dfl_postprocess`. The previous pass names are no longer accepted and raise an error.
-   **`pre_optimize` Configuration Changes (Breaking)**: The YOLO passes (`yolo_dfl_postprocess`, `yolo_no_dfl_postprocess`) now require an explicit `task` key (`base` / `seg` / `pose`). The `input_height` / `input_width` keys are removed — the input size is derived from the model input, and supplying them raises `ValueError`.

### 2. Added

-   **Segmentation QAT**: Quantization-Aware Training now supports dense segmentation models via an opt-in `task_type` block in the `qmaster` config (`seg_root`, `seg_pairs_train` / `seg_pairs_val`, `seg_ignore_index`, `seg_binary`, `seg_ce`).
-   **Optimize-Phase Accuracy Check (Debug)**: Added a `--optimize_check` debug CLI flag (with `--optimize_check_num_samples`) that re-quantizes offloaded CPU→NPU inputs and reports an accuracy check right after the optimize phase, before full compilation.
-   **GPU/CPU Quantization Toggle**: New `--use_gpu {True,False}` CLI flag and `use_gpu` Python argument to run quantization on GPU (default, when available) or force CPU. Select a specific GPU on the CLI with the `CUDA_VISIBLE_DEVICES` environment variable.
-   **Verbose Error Output**: New `--verbose` CLI flag and `verbose` Python argument that expand masked error messages with the origin type, the original message, and one bounded direct cause.
-   **`QMasterConfig`**: Public QAT configuration object exported from the top-level `dx_com` package.
-   **New `pre_optimize` Tasks**: The `task` key (`base` / `seg` / `pose`) adds pose (keypoint) and segmentation post-processing support.
-   **`rtmdet_postprocess` Pass**: RTMDet detection post-processing.
-   **`Gather` 2-D Indices**: The `Gather` operator now supports a 2-D `indices` tensor (previously limited to 0-D/1-D). See [Supported ONNX Operators](source/docs/03_Building_Models.md).
-   **`Einsum` Operator**: Two-input `Einsum` equations that reduce to a (batched) matrix multiplication (e.g., `ij,jk->ik`, `bij,bjk->bik`) are now supported. See [Supported ONNX Operators](source/docs/03_Building_Models.md).
-   **3D Convolution Support**: `Conv` and `ConvTranspose` with a 5D input (3 spatial dimensions) are now supported on the NPU (previously CPU-only), subject to constraints such as `group=1`, no dilation, and a compile-time constant weight. See [Supported ONNX Operators](source/docs/03_Building_Models.md) for the full constraints.

### Installer

### 1. Changed

-   **DX-TRON Support Removed**: `--target=dx_tron` is no longer accepted by `install.sh` or `uninstall.sh`. Valid targets are now `dx_com` and `all`.
-   **DX-TRON Launcher Scripts Removed**: `run_dxtron_web.sh` and `run_dxtron_appimage.sh` were deleted.
-   **`compiler.properties` Simplified**: `TRON_VERSION` and `TRON_DOWNLOAD_URL` were removed, leaving only `COM_VERSION`. `install.sh` no longer reads or validates the DX-TRON properties.
-   **DX-TRON DEB Removal Is Now Manual**: `uninstall.sh` no longer runs `apt-get remove dxtron`. If the `dxtron` DEB package is still installed on a Debian/Ubuntu host, remove it with `sudo apt-get remove dxtron`.
-   **`--target=all` and `--target=dx_com` Converged in `uninstall.sh`**: With DX-TRON gone the two targets perform the same work. In `install.sh` they remain distinct — `all` skips the OS/architecture check in archive mode and probes silently, while `dx_com` checks strictly.
-   **Dead Installer Internals Removed**: `scripts/install_module.sh` and `scripts/downloader.py` were deleted. They implemented the tarball download/extract/symlink flow used only by the DX-TRON installer; DX-COM has always installed via `pip`.

### 2. Fixed

-   **Leftover `dx_tron/` Cleanup**: `uninstall.sh` removes a leftover `dx_tron/` directory or symlink from an earlier release whenever it uninstalls (`--target=dx_com` or the default `all`), so upgrading does not orphan it.

### 3. Added

-   **Explicit Message for the Removed Target**: Passing `--target=dx_tron` now exits non-zero with a specific explanation instead of the generic "invalid target" error — `install.sh` points at `--target=dx_com` and the `--export_html` summary report, and `uninstall.sh` points at `sudo apt-get remove dxtron`. Existing scripts and CI jobs fail with the reason rather than a misleading message.

### Documentation

### 1. Changed

-   **Model Viewer Page Removed**: The *Model Viewer — DX-TRON* user manual page, its navigation entry and its four screenshots were removed. The page documented an install target, launcher scripts, and a binary that no longer ship, instructing readers to run commands that now fail. Use the *Compilation Summary Report* page instead.
-   **Compilation Summary Report Renumbered**: `04_02_Compilation_Summary_Report.md` became `04_Compilation_Summary_Report.md`, now that *Development Tools* holds a single document. All references were repointed.
-   **Validation Guidance Updated**: The agent-driven development knowledge base (`.deepx/`) and all generated platform instruction files now direct validation to `dxcom --export_html` and the resulting `<model_name>_summary.html` instead of DX-TRON inspection.
-   **`Resize` Supported Scale Ranges Documented**: `nearest` upsampling supports powers of two only (`2`, `4`, `8`, `16`, …). `linear` upsampling supports integer factors ≥ 2, except primes greater than `8` (`11`, `13`, `17`, …). Downsampling is supported only for `linear` at scale `0.5`; `nearest` downsampling is not supported.

----------

## DX-Compiler v2.4.1 / 2026-08-14

-   DX-COM: v2.4.0
-   DX-TRON: v2.0.1 (Deprecated)

----------

Here are the **DX-Compiler v2.4.1** Release Notes. This is a documentation-only hotfix; no changes to DX-COM or DX-TRON binaries.

### Documentation

### 1. Fixed

-   Added missing documentation for the `iqr` (Interquartile Range) calibration method.
-   Improved PPU type configuration table formatting and clarified that `PPUTypes.YOLOV8` supports multiple YOLO versions (v8, v9, v11, v12).
-   Added deprecation warning to the DX-TRON chapter directing users to the HTML graph viewer replacement.
-   Added Codex CLI to Agent-Driven Development supported tools list and scenario tables.
-   Fixed broken internal links and reorganized several pages in the user manual for improved navigation.
-   Corrected the `dx_com.pre_optimize()` supported-model listings in the user manual: YOLOv10 is not a valid target and has been removed from the `yolo_postprocess` and PPU-type-2 migration guidance.

----------

## DX-Compiler v2.4.0 / 2026-06-16

-   DX-COM: v2.4.0
-   DX-TRON: v2.0.1 (Deprecated)

----------

> **⚠️ Deprecation Notice — DX-TRON**
>
> Starting with DX-Compiler **v2.4.0**, **DX-TRON is deprecated** and will be removed in a future release. No further feature updates or bug fixes are planned for DX-TRON. We recommend migrating to the new **HTML graph viewer** bundled with DX-COM (see *Interactive HTML Graph Viewer* below) for model inspection and visualization.

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
-   Fixed several Q-PRO/DXQ quantization crashes and stability issues observed on real models.
-   Fixed multiple compilation errors and runtime issues caused by tiling, partitioning, and memory allocation in models containing `Split`, `Concat`, `Reshape`, `Bilinear Resize`, `Clip`, or odd spatial dimensions.
-   Fixed compatibility issues with **NumPy 2.4+** and **onnxruntime ≥ 1.25.0**.
-   Fixed grayscale conversion automatically squeezing one channel, which caused a dimensional difference from RGB images and required an additional `ExpandDim` pre-processing step in the config. The grayscale pre-processing config is now identical to that of RGB images.

### 3. Added

-   **Automated Q-PRO Configuration**: Q-PRO quantization (formerly available only by hand-picking DXQ combinations) is now much easier to use. DX-COM can now **automatically generate DXQ combinations** for you and run Q-PRO under the hood, removing the need to manually tune the many DXQ knobs to get higher-accuracy quantization.
-   **Quantization-Aware Training (QAT)**: Added end-to-end **QAT** support directly through `dx_com.compile()`. When the supplied config JSON includes a `qmaster` block, `dx_com.compile()` automatically switches to QAT mode and runs the training pipeline using the same dataset settings as PTQ calibration. Available from both the `dxcom` CLI and the Python API. A new `fast_run` flag is also available for quick QAT smoke tests.
-   **QXNN Resume (Re-quantization without Recompile)**: Added a checkpoint-based **QXNN resume** flow available from both the `dxcom` CLI and the Python API. Once a model has been compiled, users can re-run quantization with different settings (e.g., a different calibration method) without repeating the earlier compile phases, dramatically shortening the iteration loop when tuning quantization quality.
-   **Quantization Diagnosis Report (HTML)**: Added an HTML report that visualizes per-region quantization quality, flags high-severity regions, and includes ready-to-paste compile snippets to retry compilation with recommended settings. Enabled via the new `quant_diagnosis` option, available from both the `dxcom` CLI and `dx_com.compile()`.
-   **Interactive HTML Graph Viewer (replaces DX-TRON)**: DX-COM now produces a standalone HTML viewer for inspecting compiled models, including parameter shapes, CPU/NPU partition reasons, and cross-subgraph connections. This replaces the DX-TRON workflow (see Deprecation Notice above).
-   **`dx_com.pre_optimize()` API**: Added a new top-level `dx_com.pre_optimize()` API for applying ONNX-level pre-processing transforms before compilation, with built-in support for **YOLO post-processing** integration (detection and segmentation modes). See the [Pre-Optimize API](source/docs/02_09_Pre_Optimize_API.md) chapter of the user manual.
-   **Ubuntu 26.04 Validation**: DX-COM is now validated on **Ubuntu 26.04**, in addition to the previously supported Linux distributions.
-   **DEEPX Agent-Driven Development (`dx-agent-dev`) — Beta**: Compile models with a natural-language prompt. An AI coding agent drives DX-COM to turn ONNX/`.pt` (including Ultralytics `format=deepx`) into a deployable `.dxnn`, with ONNX-vs-DXNN numerical verification. (Beta — behavior may change.)

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function.

### Installer

### 1. Changed

-   **Expanded OS Support**: `install.sh` supported the **Red Hat family** — **Fedora 42–45**, **RHEL 9–10**, and **CentOS Stream 9–10** — in addition to **Ubuntu 20.04/22.04/24.04/26.04** and **Debian 11–13**. Required repositories (CRB/PowerTools, EPEL) and build dependencies were set up automatically. Ubuntu 18.04 was no longer supported.
-   **Expanded Python Version Support**: The installer accepted **Python 3.8–3.14** (previously 3.8–3.12), installing a supported version via the system package manager or a source build when the OS default was unsuitable.
-   **Simplified DX-COM Installation**: DX-COM was installed as a published `pip` package, so a matching wheel no longer had to be selected per Python version. `compiler.properties` no longer carried per-Python download URLs.
-   **Fully Unattended Installation**: All interactive prompts were removed — the Python version confirmation and its 10-second timeout, plus package prompts such as the `tzdata` timezone selection. `install.sh` ran to completion without user input, making it usable in Dockerfiles and CI pipelines.

### 2. Fixed

-   Fixed the installer reporting success on an unsupported OS/architecture after creating a virtual environment. It stopped early with a clear message when neither DX-COM nor DX-TRON could be installed.
-   Fixed reinstallation failures caused by leftover files or broken symlinks from a previously interrupted install.
-   Improved installation error reporting: a failed dependency step failed immediately with the actual error, instead of surfacing later as an unrelated build error.

### 3. Added

-   **DX-TRON on the Red Hat Family (Web Only)**: On Fedora/RHEL/CentOS, the web variant was installed and could be started with `./run_dxtron_web.sh`. The `dxtron` CLI/desktop build required FUSE and remained available on the Debian/Ubuntu family only.
-   **Installation in Minimal Container Images**: The installer worked in images without `sudo` (e.g., minimal UBI/RHEL images, or running as `root` in CI), instead of failing with `sudo: command not found`.

### DX-TRON (v2.0.1)

**Deprecated.** DX-TRON is deprecated as of DX-Compiler v2.4.0 and will be removed in a future release. Please migrate to the DX-COM Interactive HTML Graph Viewer for model visualization. No changes in this release.

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
-   **Expanded Linux Distribution Validation**: In addition to previously supported Ubuntu 20.04, 22.04, and 24.04, DX-COM was verified on Fedora 42–45, RHEL 9–10, and CentOS Stream 9–10 in this release.

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function. This will be resolved in an upcoming release.
-   The following models from [DX-ModelZoo](https://developer.deepx.ai/modelzoo/) show high accuracy variability depending on the host CPU and calibration dataset used: OSNet0_5, RepVGGA2, YoloV9C, DnCNN series.

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
-   Fixed PPU compilation bug in Python wheel package for Python 3.8, 3.9, and 3.10.
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

-   Resolved accuracy degradation issue in the `DeepLabV3PlusMobilenet-1` model from DX-ModelZoo.

### 3. Added

-   **New Installation Option: Python Wheel Package**
    -   Install DX-COM via `pip` for Python projects (Python 3.8, 3.9, 3.10, 3.11, 3.12).
    -   Use `dx_com.compile()` API directly in your Python code.
    -   No JSON configuration file needed (optional) - use torch DataLoader instead.
    -   Perfect for: automated workflows, Jupyter notebooks, integration with existing ML pipelines.
-   **Multi-Input Model Support** (via Python API)
    -   Compile models with multiple inputs (e.g., stereo vision, dual-stream models).
    -   Use torch DataLoader to provide data for each input independently.
-   **Extended PPU Support**
    -   YOLOv8, YOLOv9, YOLOv10, YOLOv11, YOLOv12 now compatible with hardware-accelerated post-processing.
    -   In addition to previously supported YOLOv3, YOLOv4, YOLOv5, YOLOv7.

### 4. Known Issues

-   Significant FPS degradation has been observed in models using PReLU as an activation function.

### DX-TRON (v2.0.1)

### 1. Changed

-   None

### 2. Fixed

-   None

### 3. Added

-   **New Installation Method: Debian Package (DEB)**
    -   Install via `.deb` package on Ubuntu 20.04, 22.04, and 24.04 (supports amd64, arm64).
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
-   Clarified ONNX opset version support: versions 11–21 are supported (version 22 and above are not supported).
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

-   Accuracy degradation has been observed in the `DeepLabV3PlusMobilenet-1` model from DX-ModelZoo.

----------

## DX-Compiler v2.0.0 / 2025-09-08

-   DX-COM: v2.0.0
-   DX-TRON: v2.0.0

----------

Here are the **DX-Compiler v2.0.0** Release Notes for each module.

### DX-COM (v2.0.0)

### 1. Changed

-   Compatibility with DX-RT versions earlier than v3.0.0 is not guaranteed.
-   Removed the DXQ enhanced quantization option (`enhanced_scheme`) in DX-COM v2.0.0 (reintroduced in DX-COM v2.1.0).
-   PPU (Post-Processing Unit) is no longer supported, and there are no current plans to reinstate it.

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

-   DX-TRON can now run on Linux amd64 environments and can be installed via dx-all-suite.

----------

## DX-Compiler v1.0.0 Initial Release / 2025-07-23

-   DX-COM: v1.60.1
-   DX-TRON: v0.0.8

We're excited to announce the **initial release of DX-Compiler v1.0.0!**

DX-COM is a core component of the DEEPX SDK, designed to streamline your AI development workflow by efficiently converting pre-trained ONNX models into highly optimized `.dxnn` binaries for DEEPX NPUs. This initial release marks a significant step towards enabling low-latency and high-efficiency inference on DEEPX NPU hardware.

----------

### What's New?

This v1.0.0 release introduces the foundational capabilities of DX-COM:

-   **ONNX to `.dxnn` Conversion**: Seamlessly transforms your pre-trained ONNX models into a hardware-optimized `.dxnn` binary format.
-   **JSON Configuration Support**: Utilizes an associated JSON file to define crucial pre/post-processing settings and compilation parameters, giving you fine-grained control over the optimization process.
-   **Optimized for DEEPX NPU**: Generates `.dxnn` files specifically tailored for low-latency and high-efficiency inference on DEEPX Neural Processing Units.
-   **Includes `dx_com` Module (v1.60.1)**: This version of DX-Compiler bundles the `dx_com` module, providing the core compilation functionalities.
-   **`dx_tron` Module (v0.0.8) Available**: The `dx_tron` module is also part of DX-Compiler. While its official inclusion in the main release is planned for an upcoming version, you can download `dx_tron` (v0.0.8) today from [developer.deepx.ai](https://developer.deepx.ai/).

----------

### Key Role in the DEEPX SDK

DX-COM plays a pivotal role within the broader DEEPX SDK ecosystem, interacting closely with other components to provide a complete AI development toolchain:

-   **Complements DX-RT**: The compiled `.dxnn` files are directly consumable by **DX-RT (Runtime)** for execution on DEEPX NPU hardware.
-   **Integrates with DX-ModelZoo**: Models from **DX-ModelZoo** can be compiled using DX-COM for optimized performance on DEEPX NPUs.

----------

We believe DX-Compiler v1.0.0 will be an indispensable tool for developers looking to deploy high-performance AI applications on DEEPX NPUs with minimal effort.

----------

### DX-COM (v1.60.1)

### 1. Changed

-   None

### 2. Fixed

-   None

### 3. Added

-   Initial version release of DX-Compiler. This core component of the DEEPX SDK now includes the `dx_com` module (version 1.60.1). It is designed to streamline AI development by efficiently converting pre-trained ONNX models into highly optimized `.dxnn` binaries for DEEPX NPUs, enabling low-latency and high-efficiency inference.

### DX-TRON (v0.0.8)

-   The `dx_tron` module (v0.0.8) is currently available for download at [developer.deepx.ai](https://developer.deepx.ai/). This module is part of the DX-Compiler, and its official inclusion in the main release will be in an upcoming version.
