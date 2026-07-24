---
name: dx-agent-compiler-compile
description: ONNX to DXNN compilation workflow for dx-compiler
---

<!-- AUTO-GENERATED from .deepx/ — DO NOT EDIT DIRECTLY -->
<!-- Source: .deepx/skills/dx-agent-compiler-compile/SKILL.md -->
<!-- Run: dx-agent-gen generate -->

# /dx-agent-compiler-compile — ONNX to DXNN Compilation Skill

> Step-by-step workflow for compiling ONNX models to .dxnn format
> using DEEPX DX-COM (v2.2.1).

## MANDATORY OUTPUT REQUIREMENTS — READ FIRST

> **BEFORE starting any work**, memorize these required artifacts. Every compilation
> session MUST produce ALL of these files in `${WORK_DIR}/`.
> If ANY are missing when you finish, the session is INCOMPLETE.

| # | Artifact | Required | Purpose |
|---|----------|----------|---------|
| 1 | `setup.sh` | **YES** | dx-runtime sanity check, dxcom install, venv, dx_engine, pip deps |
| 2 | `run.sh` | **YES** | One-command inference launcher with venv activation |
| 3 | `README.md` | **YES** | Session summary, quick start, file list |
| 4 | `verify.py` | **YES** | ONNX vs DXNN output comparison |
| 5 | `detect_*.py` | **YES** (if app) | Inference application |
| 6 | `*.dxnn` | **YES** | Compiled model |
| 7 | `config.json` | **YES** | DX-COM compilation config |
| 8 | `compiler.log` | **YES** | Compilation log (`--gen_log`) |
| 9 | `session.log` | **YES** | Actual command output (append each command, NOT a summary) |

> **Self-Verification**: Before presenting the final report, run this check:
> ```bash
> echo "=== Mandatory Artifact Check ==="
> for f in setup.sh run.sh verify.py session.log README.md config.json; do
>     [ -f "${WORK_DIR}/$f" ] && echo "  ✓ $f" || echo "  ✗ MISSING: $f"
> done
> ls "${WORK_DIR}"/*.dxnn >/dev/null 2>&1 && echo "  ✓ *.dxnn" || echo "  ✗ MISSING: *.dxnn"
> ```
> If ANY artifact shows `✗ MISSING`, go back and generate it. Do NOT present the
> final report with missing artifacts.

## Trigger Words

"compile", "ONNX to DXNN", "quantize", "dxcom", "INT8", "compile model"

## Prerequisites Checklist

- [ ] ONNX model validated (opset 11-21, batch=1, static shapes)
- [ ] DX-COM installed (`dxcom --help` works)
- [ ] dx-runtime sanity check passed (`bash dx-runtime/scripts/sanity_check.sh --dx_rt`)
  - If FAIL after install.sh:
    - **Compiler-only task** (compilation without dx_app/dx_stream work): inform user of the
      situation, proceed with compilation (dxcom runs on CPU), but mark verify.py as SKIPPED.
      If NPU hardware init failure: tell user cold boot / reboot is needed for verification.
    - **Cross-project task** (compilation + demo app): **STOP (unconditional)** — dx_app/dx_stream
      work requires a working NPU.
- [ ] Calibration images available (representative of inference data)
- [ ] Target device: dx_m1
- [ ] Output directory writable

## Phase -1: Model Acquisition (if no local model file)

**Gate**: A local `.onnx` model file exists for compilation.

> **NEVER reuse previous session artifacts.** Do NOT check, list, browse, or
> reference files from previous sessions in `dx-agent-dev/`. Even if a
> previous session downloaded or exported the exact same model, always
> re-download and re-export from scratch. Do NOT run `ls dx-agent-dev/`
> or check for existing `.onnx`/`.dxnn` files from past runs.

If the user did NOT provide a local `.onnx` file path, or the specified file
does not exist, the agent MUST acquire it before proceeding:

1. **Identify** the model's official download source:
   - ONNX Model Zoo, Hugging Face, framework-specific export
   - If the source model is PyTorch (`.pt`/`.pth`), route to `/dx-agent-compiler-convert`
     first, which will handle download + ONNX export

2. **Download** the model:
   ```bash
   # Example: ONNX Model Zoo
   wget -O model.onnx "<official_download_url>"

   # Example: Hugging Face
   pip install huggingface_hub
   python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='...', filename='model.onnx', local_dir='.')"
   ```

3. **Verify** the download:
   ```bash
   test -f model.onnx && echo "PASS: model downloaded" || echo "FAIL"
   ```

**NEVER** skip this phase by only generating config.json or providing download
instructions. The user expects actual compilation output (`.dxnn`), not a recipe.

**Validation gate**: Local `.onnx` file exists and is non-empty.

## Phase 0: Prepare Working Directory and Calibration Data

**Gate**: Session directory exists with calibration data symlinked.

> **NEVER reuse previous session artifacts.** Always create a new session
> directory — never reuse or reference artifacts from `dx-agent-dev/` past runs.

1. Create session working directory:
   ```bash
   SESSION_ID="$(date +%Y%m%d-%H%M%S)_$(basename model.onnx .onnx)_onnx_to_dxnn"  # local timezone (NOT UTC)
   WORK_DIR="dx-agent-dev/${SESSION_ID}"
   mkdir -p "${WORK_DIR}"
   ```

2. Check and set up calibration dataset (3-step fallback):
   ```bash
   # Step 1: User-provided custom path (if specified in prompt or context)
   if [ -n "${USER_CALIB_DIR}" ] && [ -d "${USER_CALIB_DIR}" ]; then
       CALIB_SOURCE="${USER_CALIB_DIR}"
   # Step 2: Standard location
   elif [ -d "dx_com/calibration_dataset" ] && [ -n "$(ls dx_com/calibration_dataset/ 2>/dev/null)" ]; then
       CALIB_SOURCE="dx_com/calibration_dataset"
       echo "INFO: Using sample calibration images. For best accuracy, provide domain-specific data."
   # Step 3: Auto-download
   else
       echo "Calibration dataset not found. Setting up..."
       bash example/2-download_sample_calibration_dataset.sh
       CALIB_SOURCE="dx_com/calibration_dataset"
       echo "INFO: Using sample calibration images. For best accuracy, provide domain-specific data."
   fi

   # Verify calibration data
   CALIB_COUNT=$(ls ${CALIB_SOURCE}/*.jpeg 2>/dev/null | wc -l)
   echo "Found ${CALIB_COUNT} calibration images"
   ```

3. Create calibration symlink in working directory:
   ```bash
   ln -sf "$(realpath ${CALIB_SOURCE})" "${WORK_DIR}/calibration_dataset"
   # Verify symlink resolves correctly
   ls "${WORK_DIR}/calibration_dataset/" | head -3
   ```

4. Copy ONNX model to working directory:
   ```bash
   cp model.onnx "${WORK_DIR}/"
   ```

**Validation gate**: `${WORK_DIR}/` exists. Calibration symlink resolves. ONNX model copied.

## Phase 1: Validate ONNX Model

**Gate**: Model meets all DX-COM requirements.

1. Check opset version:
   ```python
   import onnx
   model = onnx.load("model.onnx")
   opset = model.opset_import[0].version
   assert 11 <= opset <= 21, f"Opset {opset} not supported (need 11-21)"
   ```

2. Check batch size and shapes:
   ```python
   for inp in model.graph.input:
       shape = [d.dim_value for d in inp.type.tensor_type.shape.dim]
       assert shape[0] == 1, f"Batch must be 1, got {shape[0]}"
       assert all(d > 0 for d in shape), f"Dynamic dims found: {shape}"
       print(f"Input '{inp.name}': {shape}")
   ```

3. Run onnx checker:
   ```python
   onnx.checker.check_model(model)
   ```

**Validation gate**: Opset 11-21. Batch=1. All dims static. Checker passes.

## Phase 2: Generate config.json

**Gate**: Config is valid and consistent with ONNX model.

1. Extract model metadata:
   ```python
   input_name = model.graph.input[0].name
   input_shape = [d.dim_value for d in model.graph.input[0].type.tensor_type.shape.dim]
   ```

2. Determine preprocessing params:
   - YOLO models: `mean=[0.0, 0.0, 0.0]`, `std=[1.0, 1.0, 1.0]`
   - ImageNet models: `mean=[0.485, 0.456, 0.406]`, `std=[0.229, 0.224, 0.225]`
   - Custom: ask user

3. Write config.json to working directory:
   ```python
   import json
   config = {
       "inputs": {input_name: input_shape},
       "calibration_method": "ema",
       "calibration_num": 100,
       "default_loader": {
           "dataset_path": "./calibration_dataset",
           "file_extensions": ["jpeg", "png", "jpg"],
           "preprocessings": [
               {"resize": {"width": input_shape[3], "height": input_shape[2]}},
               {"normalize": {"mean": [0.0, 0.0, 0.0], "std": [1.0, 1.0, 1.0]}}
           ]
       }
   }
   with open(f"{WORK_DIR}/config.json", "w") as f:
       json.dump(config, f, indent=2)
   ```

   **IMPORTANT**: `dataset_path` MUST be the relative path `./calibration_dataset`
   pointing to the symlink created in Phase 0. Never use absolute paths.

4. Add PPU config if detection model **(ONLY if user confirmed PPU in brainstorming)**:

   > **MANDATORY**: Before adding PPU config, the agent MUST have confirmed with the
   > user during the brainstorming phase (dx-compiler-builder.md MANDATORY Q3). Default
   > is **no PPU**. If PPU was not discussed, do NOT add this section.

   **Auto-detect PPU eligibility**:
   - Model name matches detection families: YOLO*, SSD, NanoDet, DAMOYOLO, EfficientDet
   - ONNX output shape suggests detection head (e.g., `[1, 84, 8400]` or `[1, 300, 6]`)

   **PPU type determination**:
   | Model Family | PPU Type | Anchors |
   |---|---|---|
   | YOLOv3, YOLOv4, YOLOv5, YOLOv7 | 0 (anchor-based) | Required — must match training config |
   | YOLOX, YOLOv8-v12, SSD, NanoDet | 1 (anchor-free) | Not required |
   | YOLO26 | **PPU not supported** | N/A — NMS-free native; use end2end=True |

   ```python
   # Anchor-free (YOLOv8+): type 1
   # Anchor-based (YOLOv3-v7): type 0
   config["ppu"] = {
       "type": 1,
       "conf_thres": 0.25,
       "iou_thres": 0.45,
       "num_classes": 80,
       "max_det": 300
   }
   ```

   If PPU is enabled, note this in the session README.md — downstream dx-runtime
   agents will auto-detect PPU from the compiled .dxnn model and adjust example
   code accordingly.

**Validation gate**: `inputs` key matches ONNX input name exactly. Shape matches. Dataset path exists. PPU config present only if user confirmed.

## Phase 3: Prepare Calibration Data

**Gate**: Sufficient representative images accessible via symlink.

1. Verify the calibration symlink created in Phase 0:
   ```bash
   ls -la "${WORK_DIR}/calibration_dataset"
   ls "${WORK_DIR}/calibration_dataset/" | wc -l  # Should be >= calibration_num
   ```

2. Ensure images are representative of real inference data
3. Minimum: `calibration_num` images (default 100)
4. File extensions must match `file_extensions` in config
5. Verify config.json uses relative path:
   ```bash
   grep dataset_path "${WORK_DIR}/config.json"
   # Must show: "./calibration_dataset" (relative, not absolute)
   ```

**Validation gate**: Symlink resolves. File count >= calibration_num. Extensions match. Path is relative.

## Phase 4: Compile with DX-COM

**Gate**: .dxnn file produced without errors.

**CLI method** (run from working directory):
```bash
cd "${WORK_DIR}"
dxcom \
  -m model.onnx \
  -c config.json \
  -o ./ \
  --opt_level 1 \
  --gen_log
```

**Python API method**:

> **MANDATORY**: Even when using the Python API, you MUST write `config.json` to
> disk in `${WORK_DIR}/` (Phase 2) BEFORE calling `dx_com.compile()`. Pass the
> file path — never a dict — so that `config.json` exists as a required artifact.

```python
import dx_com

# config.json must already exist on disk (written in Phase 2)
dx_com.compile(
    model=f"{WORK_DIR}/model.onnx",
    output_dir=f"{WORK_DIR}/",
    config=f"{WORK_DIR}/config.json",
    opt_level=1,
    gen_log=True,
)
```

**For enhanced quantization** (higher accuracy, slower):
```python
dx_com.compile(
    model=f"{WORK_DIR}/model.onnx",
    output_dir=f"{WORK_DIR}/",
    config=f"{WORK_DIR}/config.json",
    enhanced_scheme={"DXQ-P3": {"num_samples": 1024}},
    gen_log=True,
)
```

**Validation gate**: .dxnn file exists in working directory. No error in compiler.log.

## Phase 5: Validate Output

> **CRITICAL REMINDER**: Compilation is NOT complete after `dxcom` finishes.
> You MUST complete Phase 5 → 5.5 → 5.6 → 6 in order. Do NOT jump to the
> final report. The `.dxnn` file alone is NOT a deliverable.

**Gate**: .dxnn passes inspection and produces reasonable outputs.

1. Check output artifacts:
   ```bash
   ls -la "${WORK_DIR}/"
   # Expected: model.dxnn, config.json, calibration_dataset (symlink), compiler.log
   ```

2. Inspect with DX-TRON:
   ```bash
   dx-tron --web --port 8080 "${WORK_DIR}/model.dxnn"
   ```

3. Review compiler.log for warnings:
   ```bash
   grep -i "warning\|error\|unsupported" "${WORK_DIR}/compiler.log"
   ```

**Validation gate**: .dxnn exists. No errors in log. DX-TRON loads model.

## Phase 5.5: Generate Mandatory Artifacts

**Gate**: setup.sh, run.sh, README.md, verify.py all exist in session directory.

After compilation succeeds and an inference application is generated, create these
mandatory deployment artifacts. **Never skip this phase.**

1. **setup.sh** — Environment setup:
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

   # Step 1: Verify dx-runtime installation
   if [ -f "$RUNTIME_DIR/scripts/sanity_check.sh" ]; then
       bash "$RUNTIME_DIR/scripts/sanity_check.sh" --dx_rt 2>/dev/null || \
           bash "$RUNTIME_DIR/install.sh" --all --exclude-app --exclude-stream --skip-uninstall --venv-reuse
   fi

   # Step 2: Verify dxcom installation
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

2. **run.sh** — Inference launcher with sample paths:
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

3. **README.md** — Session documentation:
   - Compilation summary (model, device, quantization method)
   - Quick start (`bash setup.sh && bash run.sh`)
   - Generated files table with sizes
   - Environment requirements
   - Verification result

4. **verify.py** — ONNX vs DXNN comparison script (see Phase 5.6)

5. **session.log** — Copilot session transcript (commands, outputs, decisions)

**Validation gate**: All 5 files exist in `${WORK_DIR}/`. `setup.sh` and `run.sh` are executable.

## Phase 5.6: TDD Verification Gate

**Gate**: verify.py runs and reports PASS — ONNX and DXNN outputs match.

This is the most critical quality gate. It catches postprocessing bugs that cause
wrong inference results even when the compiled model is correct.

1. **Generate `verify.py`**:
   - Load sample image from `dx-runtime/dx_app/sample/` — **choose based on model task**:
     | Model Task | Sample Images | Path (relative to `sample/img/`) |
     |---|---|---|
     | Object Detection (YOLO, SSD) | `sample_dog.jpg`, `sample_horse.jpg` | `img/` |
     | Face Detection | `sample_face.jpg`, `sample_crowd.jpg` | `img/` |
     | Pose Estimation | `sample_people.jpg`, `sample_crowd.jpg` | `img/` |
     | Hand Detection | `sample_hand.jpg` | `img/` |
     | OBB (Oriented BBox) | `P0177.png`, `P0284.png` | `dota8_test/` |
     | Segmentation | `sample_street.jpg`, `sample_parking.jpg` | `img/` |
     | Classification | `0.jpeg`, `1.jpeg` | `ILSVRC2012/` |
     | Super Resolution | `sample_superresolution.png` | `img/` |
     | Low-light Enhancement | `sample_lowlight.jpg`, `sample_dark_room.jpg` | `img/` |
     | Denoising | `sample_denoising.jpg` | `img/` |
   - Run ONNX inference with `onnxruntime` → ground truth detections
   - Run DXNN inference with `dx_engine` → compiled model detections
   - Apply identical postprocessing to both outputs
   - Compare results:
     - Detection count: DXNN within 20% of ONNX count
     - Class labels: top classes must match
     - Bbox IoU: average > 0.5 for matched detections

2. **Run verify.py**:
   ```bash
   cd "${WORK_DIR}"
   source venv/bin/activate
   python verify.py
   ```

3. **On PASS**: Proceed to Phase 6 (Final Report)

4. **On FAIL**: Debug the inference application:
   - Check class index mapping (0-indexed vs 1-indexed for COCO)
   - Check bbox format (xyxy vs xywh vs cxcywh)
   - Check confidence threshold and NMS parameters
   - Check output tensor shape parsing (e.g., `[1, 84, 8400]` → dim 0-3 bbox, 4-83 classes)
   - Fix the postprocessing code and re-run verify.py
   - **Do NOT proceed until PASS**

**Common verification failures**:
| Failure | Cause | Fix |
|---|---|---|
| Wrong class labels | COCO index off-by-one | Use 0-indexed classes |
| No DXNN detections | Threshold too high or wrong output parsing | Lower threshold, check tensor shape |
| Bbox coordinates wrong | Wrong format (xywh vs xyxy) | Match to model output spec |
| All same class | Class scores from wrong dimension | Check output shape carefully |

**Validation gate**: `verify.py` exists. Execution prints PASS for sample images.

## Phase 5.7: Cross-Validation with Precompiled Reference Model

**Gate**: If a precompiled DXNN for the same model exists in
`dx-runtime/dx_app/assets/models/`, run verify.py with both models to
isolate compilation issues from verify.py code bugs.

> **Skip condition**: No precompiled DXNN found → skip to Phase 6.

```bash
MODEL_NAME="<model_name>"
REF_DXNN="$SUITE_ROOT/dx-runtime/dx_app/assets/models/${MODEL_NAME}.dxnn"
if [ -f "$REF_DXNN" ]; then
    python verify.py --dxnn "$REF_DXNN" && REF=PASS || REF=FAIL
    python verify.py --dxnn "${MODEL_NAME}.dxnn" && GEN=PASS || GEN=FAIL
    echo "Cross-Validation: Reference=$REF, Generated=$GEN"
    # Both FAIL → verify.py bug | Reference PASS + Generated FAIL → compilation problem
fi
```

See `dx-dxnn-compiler.md` Phase 5.7 for the full Differential Diagnosis Decision Matrix.

## Phase 6: Final Report

> **STOP**: If you have not completed Phase 5.5 (artifacts), Phase 5.6
> (verification), and Phase 5.7 (cross-validation, if applicable),
> go back now. NEVER present results without verification.

**Gate**: User receives a clear summary of all generated files.

Before presenting the report, save the session log:

> **CRITICAL**: `session.log` must contain **actual command execution output**,
> NOT a hand-written summary. Append each command and its output immediately
> after execution. NEVER write a summary with `cat << 'EOF'`.

```bash
# ── Session Logging Pattern (append after each command) ──────────────
# At Phase 0 (start of session), initialize the log:
echo "# Session: ${SESSION_ID}" > "${WORK_DIR}/session.log"
echo "# Date: $(date)" >> "${WORK_DIR}/session.log"
echo "" >> "${WORK_DIR}/session.log"

# After EVERY command execution, immediately append the command and its
# actual output (do NOT wait until end of session):
echo "$(date '+%H:%M:%S') \$ dxcom -m model.onnx -c config.json -o ./ --gen_log" >> "${WORK_DIR}/session.log"
echo "<paste actual dxcom output here>" >> "${WORK_DIR}/session.log"
echo "" >> "${WORK_DIR}/session.log"

echo "$(date '+%H:%M:%S') \$ python verify.py" >> "${WORK_DIR}/session.log"
echo "<paste actual verify.py output here>" >> "${WORK_DIR}/session.log"
```

> **In agent/copilot environments**: Each command is a separate tool call.
> After each tool call returns, append the command line and its actual output
> to `session.log` in the next tool call. Do NOT defer logging to the end.

**What session.log MUST contain** (actual output, not summaries):
- Every shell command executed (prefixed with `$`)
- The real stdout/stderr output of each command
- Compilation output (from `dxcom`)
- Verification output (from `verify.py`)
- Any error messages and recovery steps

Generate a compilation report listing every file in the session directory:

> **STOP — Self-Verification**: Before generating the report, run the mandatory
> artifact check from the "MANDATORY OUTPUT REQUIREMENTS" section at the top
> of this document. If any artifact is missing, generate it now.

```bash
echo "## Compilation Report"
echo ""
echo "**Session**: ${WORK_DIR}/"
echo ""
echo "### Generated Files"
for f in "${WORK_DIR}"/*; do
    if [ -L "$f" ]; then
        echo "  $(basename $f) → $(readlink $f) (symlink)"
    elif [ -f "$f" ]; then
        SIZE=$(du -h "$f" | cut -f1)
        echo "  $(basename $f)  ${SIZE}"
    fi
done
```

The report should include:
- Session directory path
- Table of all generated files with sizes (must include setup.sh, run.sh, verify.py, session.log)
- Compilation statistics (NPU/CPU subgraphs, time)
- Quantization method and calibration details
- **Verification result: PASS/FAIL (from verify.py)** — MANDATORY field
- Next steps: validation with DX-TRON, deployment to dx_app

## Error Recovery

| Error | Recovery |
|---|---|
| Input name mismatch | Inspect ONNX model input name; update config.json |
| Unsupported operator | Try `--aggressive_partitioning` to offload to CPU |
| OOM on calibration | Reduce `calibration_num` or use CPU (`quantization_device: null`) |
| PPU config error | Verify type matches model architecture (0=anchor, 1=anchor-free) |
| Compilation timeout | Reduce model complexity or contact DEEPX support |
