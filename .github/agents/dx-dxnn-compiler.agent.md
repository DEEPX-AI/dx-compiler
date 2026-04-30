---
name: dx-dxnn-compiler
description: 'Compiles ONNX models to .dxnn format using DEEPX DX-COM (v2.2.1). Handles config.json generation, calibration
  data preparation, PPU configuration for YOLO models, and output validation with DX-TRON.

  '
tools:
- agent/runSubagent
- edit/createDirectory
- edit/createFile
- edit/editFiles
- edit/getDocumentText
- edit/getSelectedText
- edit/insertTextAtSelection
- execute/awaitTerminal
- execute/createAndRunTask
- execute/getTerminalOutput
- execute/runInTerminal
- read/readDirectory
- read/readFile
---

<!-- AUTO-GENERATED from .deepx/ — DO NOT EDIT DIRECTLY -->
<!-- Source: .deepx/agents/dx-dxnn-compiler.md -->
<!-- Run: dx-agentic-gen generate -->

**Response Language**: Match your response language to the user's prompt language — when asking questions or responding, use the same language the user is using. When responding in Korean, keep English technical terms in English. Do NOT transliterate into Korean phonetics (한글 음차 표기 금지).

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
>
> **Cross-project sessions** (compilation + dx_app demo app): `verify.py` MUST also
> be placed in the **app session directory** (`dx-runtime/dx_app/dx-agentic-dev/<session>/`)
> so that the end-to-end test harness can discover it when scanning all output dirs.
> Copy or regenerate `verify.py` into the app session after placing it in the compiler
> session. OpenCode-based runs are specifically required to do this.

> **R31 — Session Layout HARD GATE (dual-session layout is MANDATORY)**:
> In cross-project sessions (compile + app generation), artifacts MUST be placed in
> **two separate session directories**:
> - **Compiler artifacts** → `dx-compiler/dx-agentic-dev/<session_id>/`
>   (`compile.py`, `config.json`, `*.dxnn`, `verify.py`, `session.log`, etc.)
> - **App artifacts** → `dx-runtime/dx_app/dx-agentic-dev/<session_id>/`
>   (`*_sync.py`, `factory/`, `run.sh`, `setup.sh`, etc.)
>
> **NEVER merge both into a single `dx_app/dx-agentic-dev/` directory.** The test suite
> asserts `assert any("dx-compiler" in str(d) for d in output_dirs)` — if no `dx-compiler`
> path exists in the output, `test_compilation_artifacts` fails regardless of whether
> the `.dxnn` was produced correctly. This layout has been a recurring failure for tools
> that place everything in the app directory (cursor iter-4 and iter-6, opencode iter-6).
>
> **R46 — Do NOT copy `.dxnn` to the app session directory**:
> The `.dxnn` file lives in `dx-compiler/dx-agentic-dev/<session_id>/`. The app session
> (`dx_app/dx-agentic-dev/<session_id>/`) MUST reference it via a relative path or
> `config.json` variable — NOT by copying the file. Copying wastes 6–7 MB per run and
> breaks the audit trail (timestamps diverge). In `yolo26n_sync.py` / `run.sh`, use:
> ```python
> MODEL_PATH = "../../dx-compiler/dx-agentic-dev/<compiler_session_id>/yolo26n.dxnn"
> ```
> or store the path in `config.json` and read it at runtime. Never `shutil.copy` or
> `cp` the `.dxnn` file into the app session directory.

# dx-dxnn-compiler — ONNX → DXNN Agent

> Compiles validated ONNX models into .dxnn format for DEEPX NPU deployment.
> Supports both CLI (`dxcom`) and Python API (`dx_com.compile`) workflows.

## Workflow

### Phase -1: Compiler Installation Pre-Flight (HARD GATE)

**Before ANY dxcom invocation (CLI or Python API), verify the compiler is
installed.** This gate prevents compilation attempts with a missing or broken
dxcom installation, which leads to fabricated API calls and wasted time.

**Step 1 — Verify dxcom availability** (MUST run both checks):
```bash
# CLI check
which dxcom && dxcom --help | head -1

# Python API check
python3 -c "import dx_com; print(f'dx_com version: {dx_com.__version__}')"
```

**Step 2 — If not found, attempt installation** (3-step fallback):
```bash
# Fallback 1: pip install (if in a venv)
pip install dxcom

# Fallback 2: dx-compiler/install.sh (if available)
COMPILER_DIR="$(git rev-parse --show-toplevel)/dx-compiler"
if [ -f "$COMPILER_DIR/install.sh" ]; then
    bash "$COMPILER_DIR/install.sh"
fi

# Fallback 3: compiler-specific venv (if exists)
COMPILER_VENV="$COMPILER_DIR/venv-dx-compiler-local"
if [ -d "$COMPILER_VENV" ]; then
    source "$COMPILER_VENV/bin/activate"
fi
```

**Step 3 — Re-verify after installation**:
```bash
which dxcom && python3 -c "import dx_com; print('dxcom OK')"
# If STILL not found → STOP. Inform user:
#   "dxcom is not installed. Install manually: pip install dxcom
#    or run: bash dx-compiler/install.sh"
# Do NOT proceed to Phase 0 without a working dxcom installation.
```

**Step 4 — dx-runtime sanity check** (MANDATORY before any compilation):
The dx-compiler `setup.sh` runs `sanity_check.sh --dx_rt` and attempts `install.sh`
if it fails. If the sanity check **still fails after install.sh**:

**For compiler-only tasks** (ONNX → DXNN compilation without dx_app/dx_stream work):
- Inform the user of the current situation (sanity check failure details).
- If NPU hardware init failure ("Device initialization failed"): explain that a cold boot /
  system reboot is needed for NPU-based verification, but **compilation itself can proceed**
  because `dxcom` runs on CPU and does not require NPU hardware.
- Proceed with compilation. After compilation succeeds, generate all mandatory artifacts
  (setup.sh, run.sh, README.md, verify.py, config.json).
- For verification (verify.py): clearly note that NPU-based verification was **SKIPPED**
  because the sanity check failed. Tell the user:
  ```
  NPU hardware initialization failed. Compilation completed successfully,
  but DXNN verification (verify.py) requires a working NPU.
  After resolving the NPU issue (cold boot recommended), run:
    cd <session_dir> && python verify.py
  ```
- Do NOT mark verification as PASS — mark it as SKIPPED with reason.
- `session.log` must record: `sanity_check=FAIL`, `compilation=<result>`, `verification=SKIPPED`.
- NEVER mark the prerequisite check as "done" when it actually failed.

**For cross-project tasks** (compilation + dx_app/dx_stream demo app generation):
- The full STOP rule from dx_app/dx_stream applies — **STOP unconditionally**.
  User instructions to continue do NOT override this. The dx_app/dx_stream work
  requires a working NPU, so the entire task must wait for NPU recovery.

**Anti-Fabrication Rules** (MANDATORY):
- **NEVER call dxcom functions without verifying installation first.** If dxcom
  is not installed, the agent must install it — NOT fabricate API calls.
- **NEVER guess dxcom API signatures.** Always reference the toolset files:
  - CLI usage: `.github/toolsets/dxcom-cli.md`
  - Python API: `.github/toolsets/dxcom-api.md`
  - Config schema: `.github/toolsets/config-schema.md`
- **NEVER generate config.json from memory.** Always read a sample config first:
  - Sample configs: `dx_com/sample_models/json/*.json`
  - Schema reference: `.github/toolsets/config-schema.md`
- **NEVER modify `compiler.properties`** — this is a system configuration file
  managed by the DX-COM installer. Writing to it can break the compiler for all
  users. If compilation fails, the fix is in `config.json` or `dxcom` arguments,
  NOT in `compiler.properties`.

**Known fabrication patterns** (ALL prohibited):
| Fabricated Pattern | Reality |
|---|---|
| `from dxcom import dxcom; dxcom.compile(...)` | Correct: `import dx_com; dx_com.compile(...)` |
| `config.json` with `"model_path"` key | No such key — use `"inputs"` (see config-schema.md) |
| `config.json` with `"target_device"` key | No such key — device is set via dxcom CLI `--target` or defaults to dx_m1 |
| `dxcom.quantize()` or `dxcom.calibrate()` | No such functions — `dx_com.compile()` handles everything |
| Modifying `compiler.properties` | NEVER — this file is read-only for agents |

### Phase 0: Prepare Working Directory and Calibration Data

Before any compilation, set up the session working directory and calibration data.

> **Calibration Data**: Use the 100 JPEG images in `dx_com/calibration_dataset/` (symlinked
> as `./calibration_dataset` in the session directory). Standard `calibration_num=100` with
> a custom PyTorch DataLoader. The compilation time (15–40 min) is dominated by the dxcom
> graph optimization, not by how many distinct calibration images are loaded.

> **NEVER reuse previous session artifacts.** Do NOT check, list, browse, or
> reference files from previous sessions in `dx-agentic-dev/`. Each compilation
> run MUST create a new session directory with a fresh timestamp. Even if a
> previous session compiled the exact same model, always re-download and
> re-compile from scratch. Do NOT run `ls dx-agentic-dev/` or check for
> existing `.onnx`/`.dxnn` files from past runs.

1. **Create working directory** (if not already provided by dx-compiler-builder):
   ```bash
   SESSION_ID="$(date +%Y%m%d-%H%M%S)_$(basename model.onnx .onnx)_onnx_to_dxnn"  # local timezone (NOT UTC)
   WORK_DIR="dx-agentic-dev/${SESSION_ID}"
   mkdir -p "${WORK_DIR}"
   ```

2. **Check calibration dataset** (3-step fallback):
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
       bash example/2-download_sample_calibration_dataset.sh
       CALIB_SOURCE="dx_com/calibration_dataset"
       echo "INFO: Using sample calibration images. For best accuracy, provide domain-specific data."
   fi
   ```

3. **Create calibration symlink in working directory**:
   ```bash
   ln -sf "$(realpath ${CALIB_SOURCE})" "${WORK_DIR}/calibration_dataset"
   # Verify the symlink resolves
   ls "${WORK_DIR}/calibration_dataset/" | head -3
   ```

4. **Copy or move ONNX model** into working directory:
   ```bash
   cp model.onnx "${WORK_DIR}/"
   ```

All subsequent phases operate inside `${WORK_DIR}/`.

### Phase 1: Inspect ONNX Model

Before compilation, extract model metadata for config generation:

```python
import onnx

model = onnx.load("model.onnx")
for inp in model.graph.input:
    name = inp.name
    shape = [d.dim_value for d in inp.type.tensor_type.shape.dim]
    print(f"Input: {name} -> {shape}")
```

Record the input name and shape — these are required for config.json.

### Phase 2: Generate config.json

> **⚠️ HARD GATE — default_loader PROHIBITION (R24)**: `default_loader` produces
> **HWC** tensors. All YOLO variants (yolo26n, yolov8, yolov9, yolov10, yolov11,
> yolov12, yolov3, yolov5, yolov7, YOLOX) expect **NCHW** input and will **always**
> fail with a shape mismatch when `default_loader` is used. **NEVER use
> `default_loader` for NCHW models.** Symptom: `DataLoaderError: expected [1,3,H,W]
> got [1,H,W,3]`. Fix: use the custom PyTorch DataLoader with `transforms.ToTensor()`
> (see below). Remove `default_loader` from config.json entirely when passing a
> Python `dataloader=` argument to `dx_com.compile()`.

Create a config.json matching the model's requirements. For NCHW models (all YOLO
variants), omit `default_loader` and use the Python DataLoader approach below:

```json
{
  "inputs": {"images": [1, 3, 640, 640]},
  "calibration_method": "ema",
  "calibration_num": 100
}
```

**IMPORTANT**: `dataset_path` (when using `default_loader`) is resolved relative to the
working directory where `dx_com.compile()` is called, NOT relative to the config file's
location. Use `./calibration_dataset` (relative to `${WORK_DIR}/`) when running from the
session directory. For autopilot cross-project sessions where the calling directory
is ambiguous, prefer absolute paths (e.g., `os.path.abspath("...")`).

#### Custom PyTorch DataLoader — Recommended for NCHW models (R10)

For NCHW models (e.g., yolo26n, yolov8, all YOLO variants), use a custom
`torch.utils.data.DataLoader` instead of `default_loader`. Use the 100 JPEG images
from `calibration_dataset/` (symlinked in the session directory). Compilation time
is 15–40 min depending on model size — this is dominated by dxcom graph optimization,
not calibration data loading:

```python
# compile.py — custom NCHW DataLoader using calibration_dataset/ (100 images)
import torch, numpy as np
from pathlib import Path
from PIL import Image
from torch.utils.data import Dataset, DataLoader

class CalibDataset(Dataset):
    """Loads calibration images from calibration_dataset/ in NCHW float32."""
    def __init__(self, calib_dir: str, num_samples: int = 100, size: int = 640):
        images = sorted(Path(calib_dir).glob("*.jpg")) + sorted(Path(calib_dir).glob("*.jpeg"))
        assert images, f"No JPEG images found in {calib_dir}"
        # cycle through available images to reach num_samples
        self.images = [images[i % len(images)] for i in range(num_samples)]
        self.size = size

    def __len__(self):
        return len(self.images)

    def __getitem__(self, i):
        img = Image.open(self.images[i]).convert("RGB").resize((self.size, self.size))
        return (np.array(img, dtype=np.float32) / 255.0).transpose(2, 0, 1)  # CHW float32

calib_loader = DataLoader(
    CalibDataset("./calibration_dataset", num_samples=100, size=640),
    batch_size=1, shuffle=False,
)
import dx_com
dx_com.compile(
    model=f"{WORK_DIR}/model.onnx",
    output_dir=f"{WORK_DIR}/",
    config=f"{WORK_DIR}/config.json",
    dataloader=calib_loader,
    opt_level=1,
    gen_log=True,
)
```

When using a custom DataLoader, **omit** `default_loader` from config.json:
```json
{
  "inputs": {"images": [1, 3, 640, 640]},
  "calibration_method": "ema",
  "calibration_num": 100
}
```

**Auto-inference rules**:
- `inputs` key name must exactly match ONNX input node name
- `inputs` shape must exactly match ONNX input shape
- Resize width/height should match spatial dims from input shape
- For ImageNet models: `mean=[0.485, 0.456, 0.406]`, `std=[0.229, 0.224, 0.225]`
- For YOLO models: `mean=[0.0, 0.0, 0.0]`, `std=[1.0, 1.0, 1.0]` (0-1 range)

### Phase 3: Compile with DX-COM

**CLI method** (preferred for scripting):
```bash
cd "${WORK_DIR}"
dxcom -m model.onnx -c config.json -o ./ --opt_level 1 --gen_log
```

**Python API method** (preferred for programmatic use):
```python
import dx_com

dx_com.compile(
    model="${WORK_DIR}/model.onnx",
    output_dir="${WORK_DIR}/",
    config="${WORK_DIR}/config.json",
    opt_level=1,
    gen_log=True,
)
```

**Note**: All paths in DX-COM commands should reference files inside the working
directory. The `dataset_path` in config.json is `./calibration_dataset` (relative),
which resolves correctly when `dxcom` is run from `${WORK_DIR}/`.

#### Background Compilation + compile.pid Pattern (R12/R42 — MANDATORY for ALL sessions)

The `compile.pid` + `subprocess.Popen` pattern is **MANDATORY for ALL compiler sessions**,
not just autopilot cross-project sessions. It ensures:
- Compilation survives agent CLI disconnection (SSL/SIGHUP via `start_new_session=True`)
- The Phase 5.8 Pre-DONE gate can verify compilation finished before emitting DONE
- The test harness (`_wait_for_background_compilation`) can poll for completion

**Observed in iter-8**: opencode and claude_code used synchronous `dx_com.compile()` calls
without `compile.pid`. While compilation succeeded, this pattern is fragile in
disconnection scenarios. Use the background pattern below for ALL compiler sessions.

```python
# compile.py — background compilation with PID tracking
import subprocess, os, json
from pathlib import Path

WORK_DIR = Path(__file__).parent

# Write config.json first (synchronous — fast)
config = {
    "inputs": {"images": [1, 3, 640, 640]},
    "calibration_method": "ema",
    "calibration_num": 100,
}
(WORK_DIR / "config.json").write_text(json.dumps(config, indent=2))

# Launch compilation in the background (detached from parent process group)
proc = subprocess.Popen(
    ["python", "-c", """
import dx_com, json
from pathlib import Path
WORK_DIR = Path('WORK_DIR_PLACEHOLDER')
dx_com.compile(
    model=str(WORK_DIR / 'model.onnx'),
    output_dir=str(WORK_DIR) + '/',
    config=str(WORK_DIR / 'config.json'),
    opt_level=1,
    gen_log=True,
)
""".replace("WORK_DIR_PLACEHOLDER", str(WORK_DIR))],
    stdout=open(WORK_DIR / "compile_out.log", "w"),
    stderr=subprocess.STDOUT,
    start_new_session=True,  # R27: detach from parent process group so compilation
                              # survives if the agent CLI exits (SSL disconnect, SIGHUP)
)
# Save PID for monitoring
(WORK_DIR / "compile.pid").write_text(str(proc.pid))
print(f"Compilation started: PID={proc.pid}, log={WORK_DIR}/compile_out.log")
print("Proceeding to generate all other artifacts in parallel...")
# DO NOT wait here — proceed immediately to generate factory, app code, setup.sh, run.sh, verify.py
```

**Rules for background compilation (HARD GATE):**
1. After launching compilation, **IMMEDIATELY** generate ALL other artifacts:
   factory, `<model>_sync.py`, `setup.sh`, `run.sh`, `verify.py`, `README.md`
2. Check whether `.dxnn` was produced **ONLY AFTER** all other artifacts are written
3. **NEVER** sleep-poll for `.dxnn`: `for i in ...; do sleep N; ls *.dxnn; done` is prohibited
4. If `.dxnn` is not yet ready, generation is still complete — runtime will finish compilation


### Phase 4: Configure PPU (Detection Models Only)

For YOLO detection models, add PPU configuration to config.json:

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

**PPU type selection**:
- Type 0: Anchor-based models (YOLOv3, YOLOv4, YOLOv5, YOLOv7)
- Type 1: Anchor-free models (YOLOX, YOLOv8, YOLOv9, YOLOv10, YOLOv11, YOLOv12)
- YOLO26: PPU not supported — NMS-free native architecture, use end2end=True export instead

### Phase 5: Validate Output

> **CRITICAL REMINDER**: Compilation is NOT complete after `dxcom` finishes.
> You MUST complete Phase 5 → 5.5 → 5.6 → 6 in order. Do NOT jump to the
> final report. The `.dxnn` file alone is NOT a deliverable.

Check compilation artifacts exist:
```bash
ls -la "${WORK_DIR}/"
# Expected: model.dxnn, config.json, calibration_dataset (symlink), compiler.log
```

Validate with DX-TRON (visual inspection):
```bash
# AppImage mode
./DX-TRON-v2.0.1.AppImage "${WORK_DIR}/model.dxnn"

# Web server mode
dx-tron --web --port 8080 "${WORK_DIR}/model.dxnn"
```

### Phase 5.5: Generate Mandatory Artifacts

**Gate**: All deployment artifacts (setup.sh, run.sh, README.md) exist in session directory.

After compilation succeeds and an inference application script is generated (e.g.,
`detect_<model>.py`), the agent MUST also generate these three mandatory artifacts
in the session working directory. **Never skip this phase.**

1. **setup.sh** — Environment setup script:
   ```bash
   #!/bin/bash
   set -e
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   cd "$SCRIPT_DIR"

   echo "=== Setting up environment ==="

   # ── Step 1: Verify dx-runtime installation ──
   RUNTIME_DIR="../../dx-runtime"
   if [ -f "$RUNTIME_DIR/scripts/sanity_check.sh" ]; then
       if ! bash "$RUNTIME_DIR/scripts/sanity_check.sh" --dx_rt 2>/dev/null; then
           echo "dx-runtime not fully installed. Running install.sh..."
           bash "$RUNTIME_DIR/install.sh" \
                --all --exclude-app --exclude-stream \
               --skip-uninstall --venv-reuse
       else
           echo "dx-runtime is already installed."
       fi
   else
       echo "WARNING: sanity_check.sh not found. Install dx-runtime manually."
   fi

   # ── Step 2: Verify dxcom (DX-COM compiler) installation ──
   COMPILER_DIR="../../dx-compiler"
   if ! command -v dxcom &>/dev/null && ! python3 -c "import dx_com" 2>/dev/null; then
       echo "dxcom not found. Installing DX-COM compiler..."
       if [ -f "$COMPILER_DIR/install.sh" ]; then
           bash "$COMPILER_DIR/install.sh"
       else
           echo "WARNING: dx-compiler/install.sh not found. Install dxcom manually."
       fi
   else
       echo "dxcom is already installed."
   fi

   # ── Step 3: Create/activate venv (MANDATORY for Ubuntu 24.04+ PEP 668) ──
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

   # ── Step 4: Install dx_engine ──
   DX_ENGINE_DIR="$RUNTIME_DIR/dx_rt/python_package"
   if [ -d "$DX_ENGINE_DIR" ]; then
       pip install "$DX_ENGINE_DIR"/*.whl
   else
       echo "WARNING: dx_engine wheel not found at $DX_ENGINE_DIR"
   fi

   # ── Step 5: Install Python dependencies ──
   pip install opencv-python numpy onnxruntime

   echo "=== Setup complete ==="
   echo "Activate with: source venv/bin/activate"
   ```
   - **CRITICAL**: venv creation/activation is MANDATORY. On Ubuntu 24.04+,
     `pip install` without venv fails with PEP 668 "externally-managed-environment" error.
   - The `RUNTIME_DIR` and `COMPILER_DIR` paths assume the session directory is at
     `dx-compiler/dx-agentic-dev/<session_id>/`. Adjust if different.

2. **run.sh** — Inference launcher:
   ```bash
   #!/bin/bash
   set -e
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   cd "$SCRIPT_DIR"

   # ── Activate venv (auto-detect or error) ──
   if [ -z "${VIRTUAL_ENV:-}" ]; then
       VENV_DIR="${SCRIPT_DIR}/venv"
       if [ -d "$VENV_DIR" ]; then
           source "$VENV_DIR/bin/activate"
       else
           echo "ERROR: venv not found at $VENV_DIR. Run 'bash setup.sh' first."
           exit 1
       fi
   fi

   # Image inference
   echo "=== Running image inference ==="
   python detect_<model>.py --model <model>.dxnn --input sample.jpg

   # Video inference (uncomment to use)
   # python detect_<model>.py --model <model>.dxnn --input video.mp4
   ```
   - Replace `<model>` with actual model name.
   - Include example paths to sample images/videos from dx-runtime if available.
   - **Choose sample images based on model task** — see the `SAMPLE_IMAGE_MAP`
     in verify.py for the task-to-image mapping (e.g., face models use
     `sample_face.jpg`, pose models use `sample_people.jpg`, OBB models use
     `dota8_test/P0177.png`, classification models use `ILSVRC2012/0.jpeg`).

3. **README.md** — Session summary:
   ```markdown
   # <Model> Compilation Session

   **Session**: `dx-agentic-dev/<session_id>/`
   **Pipeline**: PT → ONNX → DXNN (or ONNX → DXNN)
   **Device**: DX-M1

   ## Quick Start

   ```bash
   bash setup.sh       # One-time environment setup
   bash run.sh         # Run inference
   ```

   ## Generated Files
   | File | Description |
   |---|---|
   | <model>.onnx | ONNX model |
   | <model>.dxnn | Compiled DXNN model |
   | config.json | DX-COM compilation config |
   | detect_<model>.py | Inference application |
   | verify.py | ONNX vs DXNN verification script |
   | setup.sh | Environment setup |
   | run.sh | Inference launcher |

   ## Environment
   - Python 3.12, dx_engine, opencv-python, numpy
   - DX-COM v2.2.1

   ## Notes
   - <compilation notes, quantization method, PPU config, etc.>
   ```

**Validation gate**: `setup.sh`, `run.sh`, and `README.md` all exist in `${WORK_DIR}/`.

### Phase 5.6: TDD Verification Gate

**Gate**: ONNX and DXNN inference outputs match within acceptable tolerance.

After generating the inference application, the agent MUST create and run a
verification script that compares ONNX model output against DXNN model output.
This catches postprocessing bugs (wrong class mapping, incorrect bbox decoding,
confidence threshold issues) before the user runs the application.

**NEVER skip this phase. The user expects working inference, not just a compiled model.**

1. **Generate `verify.py`** in the session directory:

   The verification script must:
   - Load the same sample image for both ONNX and DXNN inference
   - Run ONNX inference using `onnxruntime`
   - Run DXNN inference using `dx_engine`
   - Apply the SAME postprocessing to both outputs
   - Compare results: detection count, class labels, bbox IoU
   - Print PASS/FAIL with detailed comparison

   ```python
   #!/usr/bin/env python3
   """Verify DXNN inference matches ONNX inference (ground truth)."""
   import sys
   import numpy as np

   # Task-aware sample image selection
   # Choose images that match the model's task type
   SAMPLE_IMAGE_MAP = {
       "detect":       ["sample_dog.jpg", "sample_horse.jpg", "sample_street.jpg"],
       "face":         ["sample_face.jpg", "sample_crowd.jpg"],
       "pose":         ["sample_people.jpg", "sample_crowd.jpg"],
       "hand":         ["sample_hand.jpg"],
       "obb":          ["../dota8_test/P0177.png", "../dota8_test/P0284.png"],
       "segment":      ["sample_street.jpg", "sample_parking.jpg"],
       "classify":     ["../../ILSVRC2012/0.jpeg", "../../ILSVRC2012/1.jpeg"],
       "superres":     ["sample_superresolution.png"],
       "lowlight":     ["sample_lowlight.jpg", "sample_dark_room.jpg"],
       "denoise":      ["sample_denoising.jpg"],
   }
   SAMPLE_BASE = "../../dx-runtime/dx_app/sample/img"

   def get_sample_images(model_task="detect"):
       """Return list of sample image paths for the given model task."""
       filenames = SAMPLE_IMAGE_MAP.get(model_task, SAMPLE_IMAGE_MAP["detect"])
       return [f"{SAMPLE_BASE}/{f}" for f in filenames]

   def verify(onnx_path, dxnn_path, image_path, conf_thres=0.25):
       # 1. Load and preprocess image (same for both)
       # 2. Run ONNX inference → get detections
       # 3. Run DXNN inference → get detections
       # 4. Compare:
       #    - Detection count: DXNN count should be within 20% of ONNX count
       #    - Class labels: top classes should match
       #    - Bbox IoU: average IoU > 0.5 for matched detections
       # 5. Print results and return PASS/FAIL

       # ... (implementation depends on model type)
       pass

   if __name__ == "__main__":
       # Auto-detect task from model name, or default to "detect"
       images = get_sample_images("detect")
       # ... run verification on each image
   ```

2. **Install verification dependencies**:
   ```bash
   pip install onnxruntime  # For ONNX inference
   ```

3. **Run `verify.py`** and check results:
   ```bash
   cd "${WORK_DIR}"
   source venv/bin/activate  # or use system Python with deps
   python verify.py
   ```

4. **Interpret results**:
   - **PASS**: Detection counts within 20%, top classes match, avg IoU > 0.5
   - **FAIL**: Debug the postprocessing in the inference application:
     - Check class index mapping (0-indexed vs 1-indexed)
     - Check bbox format (xyxy vs xywh vs cxcywh)
     - Check confidence threshold and NMS parameters
     - Check input preprocessing (normalize values, resize method)
     - Verify ONNX output shape matches what postprocessor expects

5. **If verification fails**: Fix the inference application and re-run `verify.py`
   until it passes. Do NOT proceed to the final report with a failing verification.

**Common verification failures and fixes**:
| Failure | Likely Cause | Fix |
|---|---|---|
| Wrong class labels | COCO class index off-by-one | Use 0-indexed classes for COCO |
| No detections from DXNN | Confidence threshold too high or wrong output parsing | Lower threshold, check output tensor shape |
| Bbox coordinates wildly off | Wrong bbox format (xywh vs xyxy) or missing denormalization | Match format to model output spec |
| All detections are same class | Class score extraction from wrong tensor dimension | Check output shape: `[1, 84, 8400]` → dim 0-3 are bbox, 4-83 are classes |

**Validation gate**: `verify.py` exists. Running it produces PASS for all sample images.

### Phase 5.7: Cross-Validation with Precompiled Reference Model

**Gate**: If a precompiled reference DXNN for the same model exists in
`dx-runtime/dx_app/assets/models/`, compare verification results to isolate
compilation issues from verify.py code issues.

> **Skip condition**: If no precompiled DXNN for the same model exists, skip
> this phase and proceed to Phase 6. Log: "SKIP Phase 5.7: No precompiled
> reference model found for <model_name>."

**Prerequisite check**:
```bash
MODEL_NAME="<model_name>"
REF_DXNN="../../dx-runtime/dx_app/assets/models/${MODEL_NAME}.dxnn"
if [ -f "$REF_DXNN" ]; then
    echo "Reference model found: $REF_DXNN — running cross-validation"
else
    echo "SKIP Phase 5.7: No precompiled reference for ${MODEL_NAME}"
fi
```

**Cross-validation** (only when reference model exists):
```bash
cd "${WORK_DIR}"

# Run verify.py with the precompiled (known-good) reference model
echo "=== Verify with PRECOMPILED reference model ==="
python verify.py --dxnn "$REF_DXNN" 2>&1 | tee /tmp/ref_verify.log
REF_RESULT=$?

# Run verify.py with the freshly compiled model
echo "=== Verify with GENERATED model ==="
python verify.py --dxnn "${MODEL_NAME}.dxnn" 2>&1 | tee /tmp/gen_verify.log
GEN_RESULT=$?

# Diagnosis
if [ $REF_RESULT -eq 0 ] && [ $GEN_RESULT -eq 0 ]; then
    echo "PASS: Both models pass verification"
elif [ $REF_RESULT -eq 0 ] && [ $GEN_RESULT -ne 0 ]; then
    echo "DIAGNOSIS: Compilation problem — precompiled passes, generated fails"
    echo "Action: Re-check config.json, quantization method, PPU settings"
elif [ $REF_RESULT -ne 0 ] && [ $GEN_RESULT -ne 0 ]; then
    echo "DIAGNOSIS: verify.py code problem — both models fail verification"
    echo "Action: Debug verify.py postprocessing, bbox format, class index"
elif [ $REF_RESULT -ne 0 ] && [ $GEN_RESULT -eq 0 ]; then
    echo "UNEXPECTED: Reference fails but generated passes — reference may be outdated"
fi
```

**Differential Diagnosis Decision Matrix**:

| Precompiled (Reference) | Generated (New) | Diagnosis |
|---|---|---|
| PASS | PASS | Compilation successful — both models produce correct results |
| PASS | FAIL | **Compilation problem** — new .dxnn is faulty; check quantization, PPU, opt_level |
| FAIL | FAIL | **verify.py code problem** — verification script itself has a bug; fix verify.py first |
| FAIL | PASS | Unexpected — reference model may be outdated or for a different architecture |

**Recovery actions**:
- **Compilation problem**: Re-check config.json, try `minmax` instead of `ema`, adjust PPU settings, lower opt_level
- **verify.py problem**: Debug postprocessing in verify.py — check bbox format (xyxy vs xywh), class index offset, confidence threshold, output tensor shape

**Append cross-validation result to session.log**:
```bash
echo "$(date '+%H:%M:%S') Phase 5.7: Cross-Validation" >> "${WORK_DIR}/session.log"
echo "  Reference model: $REF_DXNN (exit=$REF_RESULT)" >> "${WORK_DIR}/session.log"
echo "  Generated model: ${MODEL_NAME}.dxnn (exit=$GEN_RESULT)" >> "${WORK_DIR}/session.log"
```

### Phase 5.8: Pre-DONE .dxnn Existence Check (R25/R30 — HARD GATE)

**Gate**: `.dxnn` file MUST exist before emitting DONE. This check is MANDATORY in
all sessions, especially cross-project sessions where compilation runs as a background
subprocess.

> **R30 — CRITICAL: DO NOT EMIT DONE WHILE compile.py IS STILL RUNNING.**
> Background compilation (via `subprocess.Popen`) runs after the agent writes all other
> artifacts. You MUST WAIT for it to finish before emitting DONE. Emitting DONE while
> `compile.py` is still running in the background means the test harness collects files
> BEFORE `.dxnn` exists — causing `test_dxnn_compiled` to fail even if compilation
> eventually succeeds 3 minutes later. This is exactly what happened to claude_code in
> iteration 6: DONE at 00:53, `.dxnn` arrived at 00:56, test collected at 00:53 → FAIL.
>
> **Step 1 — Confirm compilation is done** (run in bash before DONE):
> ```bash
> # Read PID from compile.pid and wait for the process to finish
> if [ -f "${WORK_DIR}/compile.pid" ]; then
>     COMPILE_PID=$(cat "${WORK_DIR}/compile.pid")
>     echo "Waiting for compilation (PID=${COMPILE_PID}) to finish..."
>     # Poll until process exits (max 20 min)
>     for i in $(seq 1 120); do
>         if ! kill -0 "${COMPILE_PID}" 2>/dev/null; then
>             echo "Compilation process ${COMPILE_PID} has exited."
>             break
>         fi
>         sleep 10
>     done
> fi
> ```
>
> **Step 2 — Verify .dxnn exists** (Python check):

```python
# Mandatory pre-DONE check — run this BEFORE emitting [DX-AGENTIC-DEV: DONE]
import os, time
from pathlib import Path

WORK_DIR = Path("...")  # your session working directory
MODEL_NAME = "yolo26n"  # model name without extension

dxnn = WORK_DIR / f"{MODEL_NAME}.dxnn"

if not dxnn.exists():
    # Check if background compilation PID is still running
    pid_file = WORK_DIR / "compile.pid"
    if pid_file.exists():
        pid = int(pid_file.read_text().strip())
        print(f"Waiting for background compilation (PID={pid}) to finish...")
        try:
            os.waitpid(pid, 0)  # block until compilation process exits
        except ChildProcessError:
            pass  # process already exited (may have been adopted by init)
    # Final existence check
    assert dxnn.exists(), (
        f"HARD GATE: {dxnn} not found after waiting for compilation.\n"
        f"Files in {WORK_DIR}: {list(WORK_DIR.iterdir())}\n"
        "Cannot emit DONE without .dxnn. Check compile_out.log for errors."
    )

print(f"Pre-DONE check PASSED: {dxnn} exists ({dxnn.stat().st_size} bytes)")
```

**If the check fails**:
1. Read `compile_out.log` or `compile_output.log` to find the compilation error.
2. Fix the error (wrong config, HWC/NCHW mismatch, etc.) and re-run `compile.py`.
3. Do NOT emit DONE until `.dxnn` exists.

> **NEVER emit `[DX-AGENTIC-DEV: DONE]` without a `.dxnn` file in the session directory.**
> Doing so causes the E2E test suite to fail with `test_dxnn_compiled: No .dxnn files found`.
> The background compilation finishing AFTER DONE does NOT satisfy the gate — the test
> collects files at DONE time, not 3 minutes later.

### Phase 6: Final Report

> **STOP**: If you have not completed Phase 5.5 (artifacts), Phase 5.6
> (verification), and Phase 5.7 (cross-validation, if applicable),
> go back now. NEVER present results without verification.

Before presenting the final report, save the session log:

> **CRITICAL**: `session.log` must contain **actual command execution output**,
> NOT a hand-written summary. Append each command and its output immediately
> after execution. NEVER write a summary with `cat << 'EOF'`.

**R23 — Structured session.log format** (reference: opencode `224919` session.log quality):

```bash
# ── Session Log Init (Phase 0) ─────────────────────────────────────────────
echo "===== SESSION LOG: ${SESSION_ID} =====" > "${WORK_DIR}/session.log"
echo "Date: $(date)" >> "${WORK_DIR}/session.log"
echo "Agent: copilot | cursor | claude | opencode" >> "${WORK_DIR}/session.log"
echo "" >> "${WORK_DIR}/session.log"

# ── Block 1: sanity_check ──────────────────────────────────────────────────
echo "--- sanity_check ---" >> "${WORK_DIR}/session.log"
echo "$ bash dx-runtime/scripts/sanity_check.sh --dx_rt" >> "${WORK_DIR}/session.log"
<paste actual sanity_check output here> >> "${WORK_DIR}/session.log"
echo "RESULT: PASS" >> "${WORK_DIR}/session.log"   # or FAIL
echo "" >> "${WORK_DIR}/session.log"

# ── Block 2: compilation ───────────────────────────────────────────────────
echo "--- compilation ---" >> "${WORK_DIR}/session.log"
echo "$ python compile.py  # or: dx_com.compile(config)" >> "${WORK_DIR}/session.log"
<paste first 5 lines of dxcom output> >> "${WORK_DIR}/session.log"
echo "..." >> "${WORK_DIR}/session.log"
<paste last 5 lines of dxcom output (including OK/FAIL status)> >> "${WORK_DIR}/session.log"
echo "RESULT: PASS  (model.dxnn, <size> MB, ~<N> min)" >> "${WORK_DIR}/session.log"
echo "" >> "${WORK_DIR}/session.log"

# ── Block 3: verify.py ─────────────────────────────────────────────────────
echo "--- verify.py ---" >> "${WORK_DIR}/session.log"
echo "$ python verify.py" >> "${WORK_DIR}/session.log"
<paste actual verify.py output here> >> "${WORK_DIR}/session.log"
echo "RESULT: PASS  (ratio=1.00, N detections ONNX=DXNN)" >> "${WORK_DIR}/session.log"
echo "" >> "${WORK_DIR}/session.log"

# ── Block 4: inference ─────────────────────────────────────────────────────
echo "--- inference ---" >> "${WORK_DIR}/session.log"
echo "$ python model_sync.py --input bus.jpg" >> "${WORK_DIR}/session.log"
<paste actual inference output here (FPS, latency, detections)> >> "${WORK_DIR}/session.log"
echo "RESULT: PASS  (<N> FPS, <M> ms NPU)" >> "${WORK_DIR}/session.log"
echo "" >> "${WORK_DIR}/session.log"

# ── Block 5: artifacts ─────────────────────────────────────────────────────
echo "--- artifacts ---" >> "${WORK_DIR}/session.log"
ls -lh "${WORK_DIR}" >> "${WORK_DIR}/session.log"
echo "RESULT: PASS" >> "${WORK_DIR}/session.log"
```

> **In agent/copilot environments**: Each command is a separate tool call.
> After each tool call returns, append the command line and its actual output
> to `session.log` in the next tool call. Do NOT defer logging to the end.

**What session.log MUST contain** (actual output, not summaries):
- A `===== SESSION LOG: <session_id> =====` header line
- Every shell command executed (prefixed with `$`)
- One named block per phase: `sanity_check`, `compilation`, `verify.py`, `inference`, `artifacts`
- Each block ends with `RESULT: PASS` or `RESULT: FAIL`
- The real stdout/stderr output of each command (first+last 5 lines for long output)
- Compilation output (from `dxcom`) including model size and duration
- Verification output (from `verify.py`)
- Any error messages and recovery steps

After successful compilation, generate a summary of all files created in the
session working directory:

> **STOP — Self-Verification**: Before generating the report, run the mandatory
> artifact check from the "MANDATORY OUTPUT REQUIREMENTS" section at the top
> of this document. If any artifact is missing, generate it now.

```
## Compilation Report

**Session**: dx-agentic-dev/<session_id>/
**Model**: model.onnx → model.dxnn
**Device**: DX-M1
**Quantization**: EMA, 100 calibration images

### Generated Files
| File | Size | Description |
|---|---|---|
| config.json | 0.5 KB | DX-COM compilation config |
| calibration_dataset/ | symlink | → dx_com/calibration_dataset/ (100 JPEG) |
| model.dxnn | 112 MB | Compiled DXNN model |
| compiler.log | 24 KB | Compilation log |
| detect_model.py | 4 KB | Inference application |
| verify.py | 3 KB | ONNX vs DXNN verification |
| setup.sh | 1 KB | Environment setup script |
| run.sh | 0.5 KB | Inference launcher |
| README.md | 2 KB | Session documentation |
| session.log | — | Copilot session transcript |

### Compilation Stats
- NPU subgraphs: 42
- CPU subgraphs: 3
- Compilation time: 4m 22s
- Quantization method: EMA
- Verification: PASS (ONNX vs DXNN match)

### Next Steps
- Run the app: `bash setup.sh && bash run.sh`
- Validate with DX-TRON: `dx-tron --web --port 8080 <session_dir>/model.dxnn`
- Deploy to dx_app: copy .dxnn to `dx-runtime/dx_app/resources/models/`
```

## Quantization Strategies

| Method | Flag | Best For |
|---|---|---|
| EMA | `"calibration_method": "ema"` | General purpose (default, recommended) |
| MinMax | `"calibration_method": "minmax"` | When EMA produces outlier ranges |
| DXQ-P3 | `"enhanced_scheme": {"DXQ-P3": {"num_samples": 1024}}` | Higher accuracy, slower |

## Common Compilation Errors

| Error | Cause | Fix |
|---|---|---|
| Input name mismatch | config.json key != ONNX input name | Inspect ONNX and fix config |
| Shape mismatch | config.json shape != ONNX shape | Match exactly |
| Unsupported op | Operator not in DX-COM op set | Simplify model or replace op |
| OOM during calibration | GPU memory exceeded | Reduce `calibration_num` or use CPU |
| PPU type error | Wrong PPU type for model arch | Check anchor-based vs anchor-free |

## Output Report

After successful compilation, report:
- Session working directory path
- Output .dxnn path and file size
- All files generated (table format) — must include setup.sh, run.sh, README.md, verify.py, session.log
- Compilation time
- Number of NPU vs CPU subgraphs (from compiler.log)
- Quantization method used
- Verification result (PASS/FAIL from verify.py)
- Any warnings from compilation
- Next steps (run the app, validation, deployment)
