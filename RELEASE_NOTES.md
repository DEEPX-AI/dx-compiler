
# RELEASE_NOTES

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

