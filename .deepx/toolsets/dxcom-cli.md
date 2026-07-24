# DX-COM CLI Reference

> Command-line reference for `dxcom` (DX-COM v2.2.1).

## Installation

```bash
pip install dx-com
# Verify installation
dxcom --help
```

## Synopsis

```
dxcom -m MODEL_PATH -c CONFIG_PATH -o OUTPUT_DIR [OPTIONS]
```

> **Note**: The binary installation uses `./dx_com/dx_com` instead of `dxcom`.
> The wheel package installs the `dxcom` command. Both have the same CLI interface.

## Required Options

| Option | Long Form | Description |
|---|---|---|
| `-m` | `--model_path` | Path to ONNX model file (.onnx) |
| `-c` | `--config_path` | Path to JSON config file (.json) |
| `-o` | `--output_dir` | Output directory for .dxnn and logs |

## Optional Flags

| Option | Long Form | Default | Description |
|---|---|---|---|
| | `--opt_level` | `1` | Optimization level: 0 (minimal) or 1 (full) |
| | `--aggressive_partitioning` | off | Maximize NPU operations |
| | `--gen_log` | off | Generate compiler.log in output directory |
| | `--compile_input_nodes` | none | Input node names for partial compilation |
| | `--compile_output_nodes` | none | Output node names for partial compilation |
| `-v` | `--version` | | Print compiler version and exit |

## Common Invocation Patterns

### Basic Compilation

```bash
dxcom -m yolov8n.onnx -c config.json -o output/
```

### With Full Optimization and Logging

```bash
dxcom \
  -m yolov8n.onnx \
  -c config.json \
  -o output/ \
  --opt_level 1 \
  --gen_log
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

## Output

Successful compilation produces:
```
output/
├── model.dxnn          # Compiled model for DEEPX NPU
└── compiler.log        # Compilation log (if --gen_log)
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
| `CUDA_VISIBLE_DEVICES` | Control GPU used for calibration |

<!-- NOTE: DXCOM_LOG_LEVEL is NOT a verified environment variable. Use --gen_log flag instead. -->

## Tips

- Always use `--gen_log` during development for debugging
- Use `--opt_level 0` for quick iteration, then `--opt_level 1` for final build
- Combine `--aggressive_partitioning` with `--gen_log` to see what was moved to NPU
- Paths can be relative or absolute
- Output directory is created automatically if it does not exist

## ⚠️ WARNING — default_loader and NCHW Models (R24)

When using the CLI (`-c config.json`), if `config.json` contains `default_loader`,
**all NCHW models will fail** with a calibration shape mismatch:

```
DataLoaderError: shape mismatch — expected [1,3,H,W] got [1,H,W,3]
```

`default_loader` produces **HWC** tensors. All YOLO variants (yolo26n, yolov8,
yolov9, v10, v11, v12, v3, v5, v7, YOLOX) expect **NCHW** input.

**Fix**: Do NOT use the CLI `dxcom` command for NCHW models with a file-based
`default_loader` config. Use the Python API instead with a custom DataLoader:

```python
import dx_com
from torch.utils.data import DataLoader
# custom_loader produces NCHW tensors via transforms.ToTensor()
dx_com.compile(model="model.onnx", output_dir="./", config="config.json",
               dataloader=custom_loader, opt_level=1, gen_log=True)
```

Remove `default_loader` from `config.json` when passing a Python `dataloader=` argument.
