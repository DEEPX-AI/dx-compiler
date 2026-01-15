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