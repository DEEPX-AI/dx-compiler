## v2.0.0 (August 2025)
- Re-enabled support for the following operators:
    - `Softmax`
    - `Slice`
- Newly added support for the following operator:
  - `ConvTranspose`
- Partial support for Vision Transformer (ViT) models:
    - Verified with the following [OpenCLIP](https://github.com/mlfoundations/open_clip) models:
        - ViT-L-14, ViT-L-14-336, ViT-L-14-quickgelu
        - RN50x64, RN50x16
        - ViT-B-16, ViT-B-32-256, ViT-B-16-quickgelu
- Compatibility with DX-RT versions earlier than v3.0.0 is not guaranteed.
- The `DXQ` option has been removed and will be reintroduced in a future release.
- `PPU(Post-Processing Unit)` is no longer supported, and there are no current plans to reinstate it.

---

## v1.60.1 (June 2025)
- Internal bug fixes.
- Added support for:
    - `-v` option: Displays **DX-COM module version**
    - `-i` option: Displays **internal module information**  
    → For usage, see: [Command Format](02_06_Execution_of_DX-COM.md#command>_format)
- The following operators were deprecated and are scheduled to be re-supported in a future release:
    - `Softmax`
    - `Slice`

---