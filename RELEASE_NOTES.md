# RELEASE_NOTES

## DX-Compiler v2.0.0 / 2025-08-11
- DX-COM: v2.0.0
- DX-TRON: v0.0.8

### 1. Changed
- Compatibility with DX-RT versions earlier than v3.0.0 is not guaranteed.
- The `DXQ` option has been removed and will be reintroduced in a future release.
### 2. Fixed
- None
### 3. Added
- Re-enabled support for the following operators:
    - `Softmax`
    - `Slice`
- Newly added support for the `ConvTranspose` operator.
- Partial support for Vision Transformer (ViT) models:
    - Verified with the following OpenCLIP models:
        - ViT-L-14, ViT-L-14-336, ViT-L-14-quickgelu
        - RN50x64, RN50x16
        - ViT-B-16, ViT-B-32-256, ViT-B-16-quickgelu

---

## DX-COM v1.60.1 / 2025-07-23

### 1. Changed
- None
### 2. Fixed
- None
### 3. Added
- Initial version release of DX-Compiler. This core component of the DEEPX SDK now includes the dx_com module (version 1.60.1). It is designed to streamline AI development by efficiently converting pre-trained ONNX models into highly optimized .dxnn binaries for DEEPX NPUs, enabling low-latency and high-efficiency inference.
- The dx_tron module (v0.0.8) is currently available for download at developer.deepx.ai. This module is part of the DX-Compiler, and its official inclusion in the main release will be in an upcoming version.

---

# DX-Compiler v1.0.0 Initial Release / 2025-07-23
- DX-COM : v1.60.1
- DX-TRON : v0.0.8

We're excited to announce the **initial release of DX-Compiler v1.0.0!**

DX-COM is a core component of the DEEPX SDK, designed to streamline your AI development workflow by efficiently converting pre-trained ONNX models into highly optimized `.dxnn` binaries for DEEPX NPUs. This initial release marks a significant step towards enabling low-latency and high-efficiency inference on DEEPX NPU hardware.

---

### What's New?

This v1.0.0 release introduces the foundational capabilities of DX-COM:

* **ONNX to `.dxnn` Conversion:** Seamlessly transforms your pre-trained ONNX models into a hardware-optimized `.dxnn` binary format.
* **JSON Configuration Support:** Utilizes an associated JSON file to define crucial pre/post-processing settings and compilation parameters, giving you fine-grained control over the optimization process.
* **Optimized for DEEPX NPU:** Generates `.dxnn` files specifically tailored for low-latency and high-efficiency inference on DEEPX Neural Processing Units.
* **Includes `dx_com` module (v1.60.1):** This version of DX-Compiler bundles the `dx_com` module, providing the core compilation functionalities.
* **`dx_tron` module (v0.0.8) available:** The `dx_tron` module is also part of DX-Compiler. While its official inclusion in the main release is planned for an upcoming version, you can download `dx_tron` (v0.0.8) today from [developer.deepx.ai](https://developer.deepx.ai).

---

### Key Role in the DEEPX SDK

DX-COM plays a pivotal role within the broader DEEPX SDK ecosystem, interacting closely with other components to provide a complete AI development toolchain:

* **Complements DX-RT:** The compiled `.dxnn` files are directly consumable by **DX-RT (Runtime)** for execution on DEEPX NPU hardware.
* **Integrates with DX ModelZoo:** Models from **DX ModelZoo** can be compiled using DX-COM for optimized performance on DEEPX NPUs.

---

We believe DX-Compiler v1.0.0 will be an indispensable tool for developers looking to deploy high-performance AI applications on DEEPX NPUs with minimal effort.

---
