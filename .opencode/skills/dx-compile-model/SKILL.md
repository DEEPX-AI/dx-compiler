---
name: dx-compile-model
description: "Step-by-step ONNX to DXNN compilation workflow using DX-COM. Covers model acquisition, validation, config generation, calibration, compilation, and mandatory post-compilation verification."
---

# /dx-compile-model — ONNX to DXNN Compilation Skill

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
>     [ -f "${WORK_DIR}/$f" ] && echo "  ok $f" || echo "  MISSING: $f"
> done
> ls "${WORK_DIR}"/*.dxnn >/dev/null 2>&1 && echo "  ok *.dxnn" || echo "  MISSING: *.dxnn"
> ```

## Trigger Words

"compile", "ONNX to DXNN", "quantize", "dxcom", "INT8", "compile model"

## Prerequisites Checklist

- [ ] ONNX model validated (opset 11-21, batch=1, static shapes)
- [ ] DX-COM installed (`dxcom --help` works)
- [ ] Calibration images available (representative of inference data)
- [ ] Target device: dx_m1
- [ ] Output directory writable

## Phase -1: Model Acquisition (if no local model file)

**Gate**: A local `.onnx` model file exists for compilation.

> **NEVER reuse previous session artifacts.** Always re-download and re-export
> from scratch. Do NOT run `ls dx-agentic-dev/` or check for existing files
> from past runs.

If the user did NOT provide a local `.onnx` file path:

1. **Identify** the model's official download source (ONNX Model Zoo, Hugging Face, etc.)
2. **Download** the model
3. **Verify** the download: `test -f model.onnx && echo "PASS"`

If the source model is PyTorch (.pt/.pth), route to `/dx-convert-model` first.

**Validation gate**: Local `.onnx` file exists and is non-empty.

## Phase 0: Prepare Working Directory and Calibration Data

**Gate**: Session directory exists with calibration data symlinked.

1. Create session working directory:
   ```bash
   SESSION_ID="$(date +%Y%m%d-%H%M%S)_$(basename model.onnx .onnx)_onnx_to_dxnn"  # local timezone (NOT UTC)
   WORK_DIR="dx-agentic-dev/${SESSION_ID}"
   mkdir -p "${WORK_DIR}"
   ```

2. Check and set up calibration dataset (3-step fallback):
   - Step 1: User-provided custom path
   - Step 2: Standard location (`dx_com/calibration_dataset`)
   - Step 3: Auto-download (`example/2-download_sample_calibration_dataset.sh`)

3. Create calibration symlink: `ln -sf "$(realpath ${CALIB_SOURCE})" "${WORK_DIR}/calibration_dataset"`

4. Copy ONNX model to working directory

**Validation gate**: `${WORK_DIR}/` exists. Calibration symlink resolves. ONNX model copied.

## Phase 1: Validate ONNX Model

**Gate**: Model meets all DX-COM requirements.

1. Check opset version (11-21)
2. Check batch size = 1 and all dims static
3. Run `onnx.checker.check_model(model)`

**Validation gate**: Opset 11-21. Batch=1. All dims static. Checker passes.

## Phase 2: Generate config.json

**Gate**: Config is valid and consistent with ONNX model.

1. Extract model metadata (input name, shape)
2. Determine preprocessing params (mean/std based on model family)
3. Write config.json with `dataset_path: "./calibration_dataset"` (relative path)
4. Add PPU config **ONLY if user confirmed** during brainstorming:
   - Type 0 = anchor-based (YOLOv3-v7)
   - Type 1 = anchor-free (YOLOX, YOLOv8-v12)
   - YOLO26 does **not** support PPU

**Validation gate**: `inputs` key matches ONNX input name. Shape matches. Dataset path exists.

## Phase 3: Prepare Calibration Data

**Gate**: Sufficient representative images accessible via symlink.

1. Verify symlink resolves
2. Ensure file count >= `calibration_num`
3. Verify config.json uses relative path

**Validation gate**: Symlink resolves. Count >= calibration_num. Path is relative.

## Phase 4: Compile with DX-COM

**Gate**: .dxnn file produced without errors.

```bash
cd "${WORK_DIR}"
dxcom -m model.onnx -c config.json -o ./ --opt_level 1 --gen_log
```

For enhanced quantization: use `enhanced_scheme={"DXQ-P3": {"num_samples": 1024}}`

**Validation gate**: .dxnn file exists. No error in compiler.log.

## Phase 5: Validate Output

1. Check output artifacts exist
2. Inspect with DX-TRON: `dx-tron --web --port 8080 model.dxnn`
3. Review compiler.log for warnings

**Validation gate**: .dxnn exists. No errors in log.

## Phase 5.5: Generate Mandatory Artifacts

**Gate**: setup.sh, run.sh, README.md, verify.py all exist in session directory.

1. **setup.sh** — venv creation (MANDATORY for Ubuntu 24.04+ PEP 668), dx-runtime check, dx_engine install
2. **run.sh** — venv activation + inference launcher
3. **README.md** — Session documentation
4. **verify.py** — ONNX vs DXNN comparison (see Phase 5.6)
5. **session.log** — Actual command execution output (NOT summaries)

**Validation gate**: All 5 files exist. setup.sh and run.sh are executable.

## Phase 5.6: TDD Verification Gate

**Gate**: verify.py runs and reports PASS.

1. Generate verify.py: ONNX inference vs DXNN inference comparison
2. Run verify.py
3. On PASS: proceed to Phase 6
4. On FAIL: debug postprocessing (class index, bbox format, threshold, output parsing)

**Validation gate**: verify.py exists. Execution prints PASS.

## Phase 6: Final Report

Generate compilation report with all artifacts, sizes, verification result.

## Error Recovery

| Error | Recovery |
|---|---|
| Input name mismatch | Inspect ONNX model input name; update config.json |
| Unsupported operator | Try `--aggressive_partitioning` to offload to CPU |
| OOM on calibration | Reduce `calibration_num` or use CPU |
| PPU config error | Verify type matches model architecture |
| Compilation timeout | Reduce model complexity or contact DEEPX support |
