# DX-COM CLI Reference

> Command-line reference for `dxcom` (DX-COM v2.5.0).

<!-- VERIFIED against source/docs/02_02_Installation_of_DX-COM.md, 02_06_Execution_of_DX-COM.md and 02_07_Quantization_Tuning_Workflow.md (v2.5.0) -->

## Installation

```bash
pip install dx-com            # into an active venv; PyPI (recommended) — or: uv pip install dx-com
# or, from the dx-compiler repo root (uses uv when available, otherwise pip):
./install.sh --target=dx_com
# Verify installation
dxcom --version
```

Wheels are tagged `manylinux_2_31_x86_64` (glibc ≥ 2.31) and support Python 3.8–3.14.
See `dxcom-api.md` → Installation for all options and the required system libraries.

## Synopsis

```
dxcom -m MODEL_PATH -c CONFIG_PATH -o OUTPUT_DIR [OPTIONS]
dxcom --checkpoint CHECKPOINT.qxnn -o OUTPUT_DIR [RESUME OPTIONS]   # QXNN resume mode
```

> **Note**: The standalone executable distribution (`./dx_com/dx_com`) is deprecated.
> Use the `dxcom` command installed by the wheel package.

> **Note**: The CLI supports **single-input models only**. For multi-input models, use
> the Python API (`dx_com.compile()` with a torch DataLoader) — see `dxcom-api.md`.

## Required Options

| Option | Long Form | Description |
|---|---|---|
| `-m` | `--model_path` | Path to ONNX model file (.onnx) |
| `-c` | `--config_path` | Path to JSON config file (.json) |
| `-o` | `--output_dir` | Output directory for .dxnn and logs |

In QXNN resume mode (`--checkpoint`), `-m` and `-c` are not required — only `-o` is.

## Optional Flags

### Performance and Resource Control

| Option | Long Form | Default | Description |
|---|---|---|---|
| | `--opt_level` | `1` | Optimization level: 0 (fast compile, higher NPU latency) or 1 (full optimization, lowest NPU latency) |
| | `--aggressive_partitioning` | off | **(Experimental)** Maximize NPU operations; may increase compile time and memory usage |
| | `--use_gpu` | `True` | **(v2.5.0)** `True` = quantize on GPU when available, otherwise CPU (same as the Python default `use_gpu=True`); `False` = force CPU. Select the GPU with `CUDA_VISIBLE_DEVICES` |
| | `--float64_calibration` | off | Use float64 precision in calibration and offset calculations for cross-CPU determinism |

### Quantization Quality and Tuning (v2.4.0+)

| Option | Long Form | Default | Description |
|---|---|---|---|
| | `--use_q_pro` | off | Automatic Q-PRO pipeline (ONNX compile path; also allowed in QXNN resume mode). Mutually exclusive with a manual `enhanced_scheme` |
| | `--quant_diagnosis` | off | Write a per-region report `quant_diagnosis/diagnosis_report.html` and a resume checkpoint `quant_diagnosis/<model>.qxnn` |
| | `--checkpoint` | none | `<path>.qxnn` — QXNN resume mode (re-quantize without recompiling). The extension must be `.qxnn`. Mutually exclusive with `-m/--model_path` |
| | `--recalibration_method` | none | **(Resume-only)** Observer override: `minmax`, `ema`, or `iqr` |
| | `--enhanced_scheme` | none | **(Resume-only)** Manual Q-PRO scheme, e.g. `P3:num_samples=1024`. For a normal compile, set `enhanced_scheme` in the JSON config instead. Mutually exclusive with `--use_q_pro` |
| | `--dataset_path` | none | **(Resume-only)** Override the calibration dataset path embedded in the checkpoint |

> **QXNN resume constraints**: resume-only flags raise an error without `--checkpoint`.
> On resume the calibration DataLoader is rebuilt from the config embedded in the `.qxnn`
> (default loader only) — resuming a compile that used a Python `dataloader=` is not
> documented. The result is written as `{checkpoint_stem}.dxnn` in `-o`.

### Debugging, Logging, and Partial Compilation

| Option | Long Form | Default | Description |
|---|---|---|---|
| | `--gen_log` | off | Generate compiler.log in output directory |
| | `--export_html` | off | Generate the Compilation Summary Report `<model_name>_summary.html` in output directory |
| | `--verbose` | off | **(v2.5.0)** Expand masked error messages (origin type, original message, one direct cause) |
| | `--compile_input_nodes` | none | Comma-separated input node names for partial compilation |
| | `--compile_output_nodes` | none | Comma-separated output node names for partial compilation |
| `-v` | `--version` | | Print compiler version and exit |

## Common Invocation Patterns

### Basic Compilation

```bash
dxcom -m yolov8n.onnx -c config.json -o output/
```

### With Full Optimization, Logging, and HTML Summary Report

Use this form for every compilation — review `<model_name>_summary.html` afterwards:

```bash
dxcom \
  -m yolov8n.onnx \
  -c config.json \
  -o output/ \
  --opt_level 1 \
  --gen_log \
  --export_html
```

### Aggressive Partitioning

Use when default compilation leaves too many ops on CPU:

```bash
dxcom \
  -m model.onnx \
  -c config.json \
  -o output/ \
  --aggressive_partitioning \
  --gen_log
```

### Minimal Optimization (Faster Compile)

```bash
dxcom \
  -m model.onnx \
  -c config.json \
  -o output/ \
  --opt_level 0
```

### Partial Compilation

Compile only a subgraph between specified nodes.
Use ONNX **operator node names** (not tensor/edge names):

```bash
dxcom \
  -m model.onnx \
  -c config.json \
  -o output/ \
  --compile_input_nodes conv1_out,conv2_out \
  --compile_output_nodes fc_out
```

### GPU / CPU Selection

```bash
# Force CPU quantization
dxcom -m model.onnx -c config.json -o output/ --use_gpu False
# Pin a specific GPU
CUDA_VISIBLE_DEVICES=1 dxcom -m model.onnx -c config.json -o output/
```

### Automatic Q-PRO

Opt-in only — use when the user asks for higher-accuracy quantization:

```bash
dxcom -m model.onnx -c config.json -o output/ --use_q_pro
```

### Quantization Diagnosis → QXNN Resume

```bash
# 1. Compile once with diagnosis (writes quant_diagnosis/diagnosis_report.html + <model>.qxnn)
dxcom -m large_model.onnx -c config.json -o output/large_model --quant_diagnosis

# 2. Re-quantize from the checkpoint without recompiling (no -m / -c)
dxcom \
  --checkpoint output/large_model/quant_diagnosis/large_model.qxnn \
  -o output/large_model_iqr \
  --recalibration_method iqr
```

Use `--use_q_pro` instead of `--recalibration_method` to run automatic Q-PRO on resume.
Full diagnose → resume loop: `source/docs/02_07_Quantization_Tuning_Workflow.md`.

## Output

Successful compilation produces:
```
output/
├── model.dxnn              # Compiled model for DEEPX NPU
├── compiler.log            # Compilation log (if --gen_log)
├── model_summary.html      # Compilation Summary Report (if --export_html)
└── quant_diagnosis/        # (if --quant_diagnosis)
    ├── diagnosis_report.html
    └── model.qxnn          # Resume checkpoint for --checkpoint
```

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | Success |
| non-zero | Error (invalid arguments, missing files, compilation failure, etc.) |

<!-- NOTE: The official docs do not define specific non-zero exit codes (e.g., 1 vs 2).
     Only 0 = success is verified. Do not fabricate distinct error codes. -->

## Environment Variables

| Variable | Description |
|---|---|
| `CUDA_VISIBLE_DEVICES` | Select the physical GPU used for quantization (e.g. `CUDA_VISIBLE_DEVICES=1 dxcom ...`) |

<!-- NOTE: DXCOM_LOG_LEVEL is NOT a verified environment variable. Use --gen_log flag instead. -->

## Tips

- Always use `--gen_log` and `--export_html` during development; review `<model_name>_summary.html` after every compile
- Add `--verbose` when an error is reported in masked/summarized form
- Use `--opt_level 0` for quick iteration, then `--opt_level 1` for final build
- Combine `--aggressive_partitioning` with `--gen_log` to see what was moved to NPU
- Choose GPU/CPU with `--use_gpu`; select a specific GPU with `CUDA_VISIBLE_DEVICES`
- Paths can be relative or absolute
- Output directory is created automatically if it does not exist

## ⚠️ WARNING — default_loader and NCHW Models (R24)

The CLI calibrates through the config's `default_loader`, which reads images as **HWC**
(BGR, uint8) and never transposes them. All YOLO variants (yolo26n, yolov8, yolov9, v10,
v11, v12, v3, v5, v7, YOLOX) and most PyTorch exports expect **NCHW** input, so their
`preprocessings` MUST end with a transpose followed by `expandDim`. Without the transpose,
calibration fails before compilation:

```
DataLoaderError: Invalid JSON Configuration for input 'images': The config specifies (1, 640, 640, 3), but model requires (1, 3, 640, 640). Please check the preprocessing configuration.
```

**Fix**: end `preprocessings` with `{"transpose": {"axis": [2, 0, 1]}}` and then
`{"expandDim": {"axis": 0}}` (always keep the final `expandDim` — see the R24 note in
`config-schema.md`). Ultralytics YOLO (RGB input scaled to `[0, 1]`):

```json
"preprocessings": [
  {"resize": {"width": 640, "height": 640}},
  {"div": {"x": 255}},
  {"convertColor": {"form": "BGR2RGB"}},
  {"transpose": {"axis": [2, 0, 1]}},
  {"expandDim": {"axis": 0}}
]
```

Use the Python API with a custom DataLoader only for multi-input models, non-image data,
or preprocessing the JSON ops cannot express (see "Custom DataLoader" in `dxcom-api.md`).
Do NOT pass `config=` together with `dataloader=` — they are mutually exclusive. Pass
calibration settings as keyword arguments and PPU settings as `ppu_config=`.
