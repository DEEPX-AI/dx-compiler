# Compilation Workflow — End-to-End Reference

> Complete PT → ONNX → DXNN pipeline reference for DEEPX DX-COM v2.2.1.
> Covers calibration best practices, quantization strategies, and PPU configuration.

## Pipeline Overview

```
PyTorch Model (.pt/.pth)
    │
    ▼
[Phase 0: Prepare Working Directory]
    │  mkdir dx-agent-dev/<session_id>/
    │  ln -sf calibration_dataset
    ▼
[Phase 1: Export to ONNX]
    │  torch.onnx.export()
    │  opset 11-21, batch=1, static shapes
    ▼
ONNX Model (.onnx)
    │
    ▼
[Phase 2: Simplify — OPTIONAL, only if user requests]
    │  onnx-simplifier (skip by default)
    ▼
Simplified ONNX (.onnx)
    │
    ▼
[Phase 3: Generate config.json]
    │  Input shapes, calibration (relative path), preprocessing
    ▼
[Phase 4: Verify Calibration Data]
    │  Symlink in working directory → dx_com/calibration_dataset/
    ▼
[Phase 5: Compile with DX-COM]
    │  dxcom CLI or dx_com.compile()
    ▼
DXNN Model (.dxnn)
    │
    ▼
[Phase 6: Validate with DX-TRON]
    │  Visual inspection, graph review
    ▼
[Phase 6.5: Generate Mandatory Artifacts]
    │  setup.sh, run.sh, README.md, verify.py
    ▼
[Phase 6.6: TDD Verification Gate]
    │  ONNX vs DXNN comparison → must PASS
    ▼
[Phase 7: Final Report]
    │  List all generated files, compilation stats, verification result
    ▼
Deployment Ready
```

## Phase 1: PyTorch to ONNX Export

### Key Parameters
| Parameter | Value | Notes |
|---|---|---|
| `opset_version` | 13 (recommended) | Range: 11-21 |
| `dynamic_axes` | `None` | DEEPX requires static shapes |
| Batch size | 1 | Only batch=1 supported |
| `input_names` | Descriptive name | Must match config.json `inputs` key |

### Model-Specific Export Notes

**Classification (ResNet, EfficientNet, etc.)**:
- Input: `[1, 3, 224, 224]` typically
- Single output tensor

**Detection (YOLO family)**:
- Input: `[1, 3, 640, 640]` typically
- Multiple output heads (may need to specify output_names)
- Requires PPU configuration in config.json
- **Ultralytics YOLO (v8+)**: Must set `Detect.export=True` before manual
  `torch.onnx.export()`, or use `model.export(format="onnx")`. Without this,
  the export produces 6 output nodes instead of 1. See Pitfall #10.
- **`end2end` option**: `True` → `[1, 300, 6]` NMS-included output;
  `False` → `[1, 84, 8400]` fused output requiring standard NMS postprocessing

**Segmentation**:
- Input shape varies by model
- Output is spatial feature map

## Phase 2: ONNX Simplification (OPTIONAL — Only If User Explicitly Requests)

> **WARNING**: Do NOT run onnx-simplifier automatically. Only perform this step
> if the user explicitly asks for simplification. Skip by default.

If the user explicitly requests simplification:
```bash
pip install onnx-simplifier
python -m onnxsim model.onnx model_simplified.onnx
```

Benefits (when appropriate):
- Folds constant operations
- Removes redundant nodes
- May improve DX-COM compatibility for some models

**Risks of automatic simplification**:
1. **Numerical precision loss**: Constant folding may introduce FP32 rounding errors
2. **Debugging difficulty**: Original PyTorch layer/node names are altered
3. **Model breakage**: Complex control flow or custom ops may produce incorrect graphs
4. **Input name changes**: Simplifier may rename input nodes, causing config.json mismatch

After simplification, always re-verify input names match config.json.

## Phase 3: Config Generation

### Auto-Inference Rules

Agents should auto-infer config values when possible:

1. **Input name**: Read from ONNX model's `graph.input[0].name`
2. **Input shape**: Read from ONNX model's input tensor shape
3. **Resize dims**: Extract H, W from input shape `[1, C, H, W]`
4. **Normalize params**: Infer from model family:
   - YOLO: `mean=[0,0,0]`, `std=[1,1,1]`
   - ImageNet: `mean=[0.485,0.456,0.406]`, `std=[0.229,0.224,0.225]`
5. **PPU type**: Infer from model name:
   - "yolov3", "yolov4", "yolov5", "yolov7" → type 0
   - "yolox", "yolov8", "yolov9", "yolov10", "yolov11", "yolov12" → type 1
   - "yolo26" → PPU not supported (NMS-free native architecture; use end2end=True instead)

## Phase 4: Calibration Best Practices

### Calibration Dataset Setup

Before compilation, ensure calibration data is available and properly linked:

1. **Check existing data**: Look for `dx_com/calibration_dataset/` (100 JPEG images)
2. **Auto-setup**: If missing, run `example/2-download_sample_calibration_dataset.sh`
   which downloads from `https://sdk.deepx.ai/` and extracts to `dx_com/calibration_dataset/`
3. **Working directory symlink**: Create a symlink in the session directory:
   ```bash
   ln -sf ../../dx_com/calibration_dataset dx-agent-dev/<session_id>/calibration_dataset
   ```
4. **Relative path in config.json**: Always use `"dataset_path": "./calibration_dataset"`
   in config.json. This relative path resolves from the working directory where `dxcom`
   is executed.

### Calibration Path Chain
```
dx-agent-dev/<session_id>/calibration_dataset  (symlink)
    → ../../dx_com/calibration_dataset/           (actual data: 100 JPEG)
```

### Dataset Requirements
- Images must be representative of real inference data
- Minimum: 100 images (default `calibration_num`)
- More images = better quantization accuracy (diminishing returns after ~500)
- Avoid synthetic or augmented data for calibration

### Calibration Methods

| Method | Config Value | When to Use |
|---|---|---|
| EMA | `"ema"` | Default. Best for most models |
| MinMax | `"minmax"` | When EMA produces poor accuracy |

### Q-PRO (DXQ-P0 ~ DXQ-P5) — Advanced, NOT Default

Q-PRO enhanced quantization (`enhanced_scheme`) provides higher accuracy but is
3-5x slower and requires GPU. **Do NOT use by default.** Only apply when:
1. End-user explicitly requests Q-PRO/DXQ-P/enhanced quantization
2. GPU is available and verified (`quantization_device: "cuda:0"`)
3. User confirms they accept the additional calibration time

### GPU Calibration
Use GPU for faster calibration:
```json
{"quantization_device": "cuda:0"}
```
Falls back to CPU if GPU unavailable.

## Phase 5: Compilation Options

### Optimization Levels
| Level | Description |
|---|---|
| 0 | Minimal optimization — faster compilation, larger model |
| 1 | Full optimization (default) — slower compilation, smaller model |

### Aggressive Partitioning
Use `--aggressive_partitioning` to maximize operations on NPU:
- May increase NPU coverage at cost of slight accuracy loss
- Recommended when CPU fallback ratio is high

### Partial Compilation
Compile only a subgraph of the model:
```bash
dxcom -m model.onnx -c config.json -o output/ \
  --compile_input_nodes node_a node_b \
  --compile_output_nodes node_x node_y
```

## Phase 6: PPU Configuration Guide

### PPU Type 0 — Anchor-Based

For YOLOv3, YOLOv4, YOLOv5, YOLOv7:
```json
{
  "ppu": {
    "type": 0,
    "conf_thres": 0.25,
    "iou_thres": 0.45,
    "num_classes": 80,
    "anchors": [[10,13,16,30,33,23],[30,61,62,45,59,119],[116,90,156,198,373,326]]
  }
}
```

### PPU Type 1 — Anchor-Free

For YOLOX, YOLOv8, YOLOv9, YOLOv10, YOLOv11, YOLOv12:
```json
{
  "ppu": {
    "type": 1,
    "conf_thres": 0.25,
    "iou_thres": 0.45,
    "num_classes": 80,
    "max_det": 300
  }
}
```

## Phase 6.5: Generate Mandatory Artifacts

After compilation and inference application generation, the agent MUST produce
these mandatory artifacts in the session directory. **Never skip this phase.**

### Required Files

| File | Purpose |
|---|---|
| `setup.sh` | Checks dx-runtime via sanity_check.sh, installs missing components, checks dxcom, creates venv, installs dx_engine + deps |
| `run.sh` | One-command inference launcher with example image/video paths |
| `README.md` | Session summary: pipeline, generated files table, quick start, environment notes |
| `verify.py` | Compares ONNX vs DXNN inference output to catch postprocessing bugs |
| `session.log` | Copilot session transcript: commands executed, config choices, compilation output, verification results |

### setup.sh Template

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$SCRIPT_DIR"

# Auto-detect suite root
SUITE_ROOT="$SCRIPT_DIR"
while [ "$SUITE_ROOT" != "/" ]; do
    if [ -d "$SUITE_ROOT/dx-runtime" ] && [ -d "$SUITE_ROOT/dx-compiler" ]; then
        break
    fi
    SUITE_ROOT="$(dirname "$SUITE_ROOT")"
done
if [ "$SUITE_ROOT" = "/" ]; then
    echo "ERROR: Cannot find dx-all-suite root (expected dx-runtime/ and dx-compiler/ siblings)"
    exit 1
fi

RUNTIME_DIR="$SUITE_ROOT/dx-runtime"
COMPILER_DIR="$SUITE_ROOT/dx-compiler"

# Step 1: Verify dx-runtime (dx_rt, driver, firmware)
if [ -f "$RUNTIME_DIR/scripts/sanity_check.sh" ]; then
    bash "$RUNTIME_DIR/scripts/sanity_check.sh" --dx_rt 2>/dev/null || \
        bash "$RUNTIME_DIR/install.sh" --all --exclude-app --exclude-stream --skip-uninstall --venv-reuse
fi

# Step 2: Verify dxcom (DX-COM compiler)
if ! command -v dxcom &>/dev/null && ! python3 -c "import dx_com" 2>/dev/null; then
    [ -f "$COMPILER_DIR/install.sh" ] && bash "$COMPILER_DIR/install.sh"
fi

# Step 3: Create/activate venv (MANDATORY for Ubuntu 24.04+ PEP 668)
if [ -z "${VIRTUAL_ENV:-}" ]; then
    VENV_DIR="${SCRIPT_DIR}/venv"
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating virtual environment at $VENV_DIR ..."
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    echo "Activated venv: $VENV_DIR"
else
    echo "Already in venv: $VIRTUAL_ENV"
fi

# Step 4: Install dx_engine
DX_ENGINE_DIR="$RUNTIME_DIR/dx_rt/python_package"
[ -d "$DX_ENGINE_DIR" ] && pip install "$DX_ENGINE_DIR"/*.whl

# Step 5: Install Python dependencies
pip install opencv-python numpy onnxruntime
echo "Setup complete. Activate: source venv/bin/activate"
```

**CRITICAL**: venv creation/activation is MANDATORY. On Ubuntu 24.04+,
`pip install` without venv fails with PEP 668 "externally-managed-environment" error.

### run.sh Template

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$SCRIPT_DIR"

# Auto-detect suite root
SUITE_ROOT="$SCRIPT_DIR"
while [ "$SUITE_ROOT" != "/" ]; do
    if [ -d "$SUITE_ROOT/dx-runtime" ] && [ -d "$SUITE_ROOT/dx-compiler" ]; then
        break
    fi
    SUITE_ROOT="$(dirname "$SUITE_ROOT")"
done
if [ "$SUITE_ROOT" = "/" ]; then
    echo "ERROR: Cannot find dx-all-suite root (expected dx-runtime/ and dx-compiler/ siblings)"
    exit 1
fi

# Activate venv (auto-detect or error)
if [ -z "${VIRTUAL_ENV:-}" ]; then
    VENV_DIR="${SCRIPT_DIR}/venv"
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate"
    else
        echo "ERROR: venv not found at $VENV_DIR. Run 'bash setup.sh' first."
        exit 1
    fi
fi

python detect_<model>.py --model <model>.dxnn --input "$SUITE_ROOT/dx-runtime/dx_app/sample/img/sample_dog.jpg"
```

## Phase 6.6: TDD Verification Gate

**MANDATORY**: Before the final report, verify that DXNN inference produces
correct results by comparing against ONNX inference (ground truth).

### Why This Phase Exists

Quantized DXNN models may produce correct benchmark FPS but wrong inference results
due to postprocessing bugs in the generated application code:
- Wrong class index mapping (off-by-one, wrong label file)
- Incorrect bbox decoding (xywh vs xyxy, missing denormalization)
- Confidence threshold issues (applied before vs after NMS)
- Output tensor shape misparsing (transposed dimensions)

### Verification Process

1. **Generate `verify.py`** that:
   - Loads a sample image from `dx-runtime/dx_app/sample/` — **select based on model task**:
     | Task | Sample Images |
     |---|---|
     | Object Detection | `img/sample_dog.jpg`, `img/sample_horse.jpg` |
     | Face Detection | `img/sample_face.jpg`, `img/sample_crowd.jpg` |
     | Pose Estimation | `img/sample_people.jpg`, `img/sample_crowd.jpg` |
     | Hand Detection | `img/sample_hand.jpg` |
     | OBB | `dota8_test/P0177.png`, `dota8_test/P0284.png` |
     | Segmentation | `img/sample_street.jpg`, `img/sample_parking.jpg` |
     | Classification | `ILSVRC2012/0.jpeg`, `ILSVRC2012/1.jpeg` |
     | Super Resolution | `img/sample_superresolution.png` |
     | Low-light | `img/sample_lowlight.jpg`, `img/sample_dark_room.jpg` |
     | Denoising | `img/sample_denoising.jpg` |
   - Runs ONNX inference using `onnxruntime`
   - Runs DXNN inference using `dx_engine`
   - Applies identical postprocessing to both outputs
   - Compares: detection count (within 20%), class labels (top-K match), bbox IoU (avg > 0.5)

2. **Run** `verify.py` in the session venv

3. **Interpret**:
   - PASS → proceed to Final Report
   - FAIL → debug postprocessing, fix, re-verify until PASS

4. **Never skip**: A failing verification means the inference application has bugs.
   The user will get wrong results. Fix before reporting success.

5. **Cross-validate with precompiled reference** (if available):
   If `dx-runtime/dx_app/assets/models/` has a precompiled DXNN for the same model,
   run verify.py with both to isolate compilation vs verify.py issues:
   - Both fail → verify.py bug
   - Reference passes, generated fails → compilation problem
   See `dx-dxnn-compiler.md` Phase 5.7 for details.

## Troubleshooting Checklist

When compilation fails:
1. Verify ONNX model passes `onnx.checker.check_model()`
2. Verify config.json `inputs` key matches ONNX input name exactly
3. Verify batch size is 1
4. Verify no dynamic dimensions
5. Verify opset is 11-21
6. Check calibration data path exists and contains images
7. Try with `--gen_log` and inspect compiler.log
8. Try with `--aggressive_partitioning` for unsupported ops
9. Try simplifying the ONNX model (only if not already simplified and user approves)
10. Verify ONNX has single output node (multi-output = Ultralytics export flag issue)
11. Contact DEEPX support with compiler.log

## Sample Model Workflow (example/ Scripts)

The `example/` directory contains a complete 3-step workflow for downloading,
calibrating, and compiling sample models. Agents should reference these scripts
when users want to test with sample models or learn the compilation process.

### Step 1: Download Sample Models

```bash
cd dx-compiler
./example/1-download_sample_models.sh
```

Downloads 3 sample models from `https://sdk.deepx.ai/`:
- `YOLOV5S-1` — YOLOv5s object detection
- `YOLOV5S_Face-1` — YOLOv5s face detection
- `MobileNetV2-1` — MobileNetV2 classification

Output structure:
```
dx-compiler/dx_com/sample_models/
├── onnx/
│   ├── YOLOV5S-1.onnx
│   ├── YOLOV5S_Face-1.onnx
│   └── MobileNetV2-1.onnx
└── json/
    ├── YOLOV5S-1.json
    ├── YOLOV5S_Face-1.json
    └── MobileNetV2-1.json
```

The JSON files contain pre-built config.json for each model (input shapes,
preprocessing, calibration settings, PPU config where applicable).

### Step 2: Download Calibration Dataset

```bash
cd dx-compiler
./example/2-download_sample_calibration_dataset.sh
```

- Downloads `calibration_dataset.tar.gz` from `https://sdk.deepx.ai/dataset/`
- Extracts to `dx_com/calibration_dataset/` (100 JPEG images)
- Patches `dataset_path` in all sample JSON configs to `./calibration_dataset`
- Download cache: `dx_com/download/calibration_dataset.tar.gz`

### Step 3: Compile Sample Models

```bash
cd dx-compiler
./example/3-compile_sample_models.sh
```

- Installs `dx-compiler` (via `install.sh`) if `dxcom` is not available
- Activates the `venv-dx-compiler` virtual environment
- Compiles all 3 sample models sequentially:
  ```
  dxcom -m dx_com/sample_models/onnx/{MODEL}.onnx \
        -c dx_com/sample_models/json/{MODEL}.json \
        -o dx_com/output/
  ```
- Runs from `dx_com/` so that `./calibration_dataset` in JSON configs resolves correctly
- Output: `dx_com/output/{MODEL}.dxnn`

### Using Sample JSON Configs as Reference

The sample JSON configs downloaded in Step 1 serve as canonical examples for
agents generating config.json for new models. Key patterns to observe:

- How `inputs` keys match ONNX input node names
- How `dataset_path` uses relative paths (`./calibration_dataset`)
- How PPU type and parameters are configured for YOLOv5 (anchor-based, type 0)
- How preprocessing (resize, normalize) parameters are set per model family

Agents should read a sample JSON config when generating config.json for a
similar model type.
