## v2.0.0 (August 2025)
- Re-enabled support for the following operators:
    - `Softmax`
    - `Slice`
- Newly added support for the following operator:
  - `ConvTranspose`
- Partial support for Vision Transformer (ViT) models:
    - Google ViT (via Hugging Face)
    - [OpenCLIP Model](https://github.com/mlfoundations/open_clip)
- Compatibility is not guaranteed with versions of DX-RT earlier than v3.0.0.
- The `DXQ` option has been removed and will be reintroduced in a future release.

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