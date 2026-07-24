## Overview

The **Compilation Summary Report** is a self-contained HTML report that summarizes the result of a DX-COM compilation. When enabled, DX-COM writes a single `<model_name>_summary.html` file into the output directory after the `.dxnn` file is generated.

Because the report embeds all of its assets, it can be opened directly in any web browser and shared as a single file — without copying the rest of the output directory. It provides a quick, install-free view of the compiled model, similar to the [DX-TRON Model Viewer](04_01_Model_Viewer_DX-TRON.md).

**Key Features**

- **Self-contained HTML**: A single file with all styles and scripts embedded; open it in any browser.
- **Model overview**: Model name, original file name, total parameter count, and original ONNX vs compiled `.dxnn` file sizes.
- **Input/Output tensors**: Names and shapes of the model inputs and outputs (using the compiled graph's static shapes when available).
- **Compilation settings**: Optimization level, aggressive partitioning, calibration method and sample count, quantization scheme, target NPU device, and compiler version.
- **Interactive graph viewer**: Pan/zoom visualization of the compiled graph with NPU vs CPU workload distribution and per-partition CPU-fallback reasons.

---

## Generating the Report

The report is generated as part of compilation by adding the `--export_html` option (CLI) or `export_html=True` (Python API). It is disabled by default.

### CLI

```bash
dxcom \
-m sample/MobilenetV1.onnx \
-c sample/MobilenetV1.json \
-o output/mobilenetv1 \
--export_html
```

### Python Module

```python
import dx_com

dx_com.compile(
    model="model.onnx",
    output_dir="./compiled",
    config="config.json",
    export_html=True,
)
```

!!! note "NOTE"
    `--export_html` / `export_html=True` is also documented as a compilation option in [Execution of DX-COM](02_06_Execution_of_DX-COM.md).

---

## Output

On success, the report is written to the output directory and the compiler prints a confirmation line:

```text
[dx_com] Summary HTML saved to: output/mobilenetv1/MobilenetV1_summary.html
```

| Item | Detail |
| :--- | :--- |
| File name | `<model_name>_summary.html` (derived from the input ONNX file name) |
| Location | The compilation `output_dir` |
| Format | Self-contained HTML (no external files required) |

Open the file in any web browser to view the report.

---

## Requirements

The report renderer relies on the `jinja2` library, which is included as a built-in dependency of DX-COM and is normally already available. No additional setup is required for a standard installation.

---

## Troubleshooting

!!! note "Compilation is never blocked by the report"
    Generating the HTML report is a best-effort, post-compilation step. If the report cannot be produced, DX-COM emits a warning and the compilation still completes successfully — the `.dxnn` output is unaffected.

- **No HTML file is produced**: Confirm that `--export_html` (or `export_html=True`) was specified, and check the compilation logs for a warning indicating the report was skipped or failed.
- **Report opens but the graph is empty**: Ensure the compilation produced a valid `.dxnn` file in the same `output_dir`; the graph viewer uses the compiled graph.

---
