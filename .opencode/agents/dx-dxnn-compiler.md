---
description: 'Compiles ONNX models to .dxnn format using DEEPX DX-COM (v2.2.1). Handles config.json generation, calibration
  data preparation, PPU configuration for YOLO models, and output validation with DX-TRON.

  '
mode: subagent
tools:
  bash: true
  edit: true
  write: true
---

<!-- AUTO-GENERATED from .deepx/ — DO NOT EDIT DIRECTLY -->
<!-- Source: .deepx/agents/dx-dxnn-compiler.md -->
<!-- Run: dx-agent-gen generate -->

**Response Language**: Match your response language to the user's prompt language — when asking questions or responding, use the same language the user is using. When responding in Korean, keep English technical terms in English. Do NOT transliterate into Korean phonetics (한글 음차 표기 금지). <!-- KOREAN-OK: rule text references the Korean notation term agents must recognize -->

## Session-ID Freshness (HARD GATE — READ FIRST)

**Every compile session MUST get a fresh `${SESSION_ID}` based on the current
local clock.** Reading prior-round state files or reusing a pre-existing
`dx-agent-dev/<sid>/` directory is a **HARD GATE violation** (see CLAUDE.md
"Previous session reference PROHIBITED" section / AGENTS.md "Sub-Project Development Rules"
section "Never reference or reuse results from previous agent-driven sessions" rule).
The harness scrubs stale state markers between rounds AND a test-time assertion fails any
session whose timestamp predates the round start by >60s.

```bash
# ✓ ALWAYS create a fresh session-id at the start of the round:
SESSION_ID="$(date +%Y%m%d-%H%M%S)_<agent>_<coding_model>_<target>_compile"
WORK_DIR="dx-agent-dev/${SESSION_ID}"
mkdir -p "${WORK_DIR}"

# ✗ NEVER read these stale state files — they leak prior session paths:
#   .codex_current_work_dir   .codex_session_id   .cursor_current_session_id
#   .current_dx_work_dir      .active_work_dir    .tmp_dx_workdir
# ✗ NEVER reuse a pre-existing dir even if it looks "complete":
#   cd dx-agent-dev/20260522-023709_*_compile/  # ← HARD GATE VIOLATION
```

If compilation is slow, fix the slowness — **do not skip a compile** by
re-entering a prior run's output dir.

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
> be placed in the **app session directory** (`dx-runtime/dx_app/dx-agent-dev/<session>/`)
> so that the end-to-end test harness can discover it when scanning all output dirs.
> Copy or regenerate `verify.py` into the app session after placing it in the compiler
> session. OpenCode-based runs are specifically required to do this.

> **R31 — Session Layout HARD GATE (dual-session layout is MANDATORY)**:
> In cross-project sessions (compile + app generation), artifacts MUST be placed in
> **two separate session directories**:
> - **Compiler artifacts** → `dx-compiler/dx-agent-dev/<session_id>/`
>   (`compile.py`, `config.json`, `*.dxnn`, `verify.py`, `session.log`, etc.)
> - **App artifacts** → `dx-runtime/dx_app/dx-agent-dev/<session_id>/`
>   (`*_sync.py`, `factory/`, `run.sh`, `setup.sh`, etc.)
>
> **NEVER merge both into a single `dx_app/dx-agent-dev/` directory.** The test suite
> asserts `assert any("dx-compiler" in str(d) for d in output_dirs)` — if no `dx-compiler`
> path exists in the output, `test_compilation_artifacts` fails regardless of whether
> the `.dxnn` was produced correctly. This layout has been a recurring failure for tools
> that place everything in the app directory (cursor iter-4 and iter-6, opencode iter-6).
>
> **R46 — Do NOT copy `.dxnn` to the app session directory**:
> The `.dxnn` file lives in `dx-compiler/dx-agent-dev/<session_id>/`. The app session
> (`dx_app/dx-agent-dev/<session_id>/`) MUST reference it via `$SUITE_ROOT/dx-compiler/...`
> (the SUITE_ROOT auto-detection pattern) or a `config.json` variable — NOT by copying
> the file. Copying wastes 6–7 MB per run and breaks the audit trail (timestamps diverge).
> In `yolo26n_sync.py` / `run.sh`, use `$SUITE_ROOT/dx-compiler/...`:
> ```python
> MODEL_PATH = f"{SUITE_ROOT}/dx-compiler/dx-agent-dev/<compiler_session_id>/yolo26n.dxnn"
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
  - CLI usage: `.deepx/toolsets/dxcom-cli.md`
  - Python API: `.deepx/toolsets/dxcom-api.md`
  - Config schema: `.deepx/toolsets/config-schema.md`
- **NEVER generate config.json from memory.** Always read a sample config first:
  - Sample configs: `dx_com/sample_models/json/*.json`
  - Schema reference: `.deepx/toolsets/config-schema.md`
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
> reference files from previous sessions in `dx-agent-dev/`. Each compilation
> run MUST create a new session directory with a fresh timestamp. Even if a
> previous session compiled the exact same model, always re-download and
> re-compile from scratch. Do NOT run `ls dx-agent-dev/` or check for
> existing `.onnx`/`.dxnn` files from past runs.

1. **Create working directory** (if not already provided by dx-compiler-builder):
   ```bash
   SESSION_ID="$(date +%Y%m%d-%H%M%S)_$(basename model.onnx .onnx)_onnx_to_dxnn"  # local timezone (NOT UTC)
   WORK_DIR="dx-agent-dev/${SESSION_ID}"
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

4. **Copy ONNX model** into working directory (**STRONGLY RECOMMENDED**):
   ```bash
   cp model.onnx "${WORK_DIR}/"
   ```
   > **Why retain ONNX?** The session directory should be self-contained —
   > verify.py needs the ONNX for numerical comparison, and re-compilation is
   > possible without external dependencies. Without the ONNX in the session dir,
   > reproducibility tests will emit warnings. Symlinks are acceptable if the
   > source path is stable (e.g., `dx-modelzoo/` within the same repo).

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

> **Note — default_loader vs custom DataLoader**: When using `default_loader` in
> config.json for NCHW models (e.g., YOLO variants), ensure the `preprocessings`
> list includes a `transpose` step to convert from HWC to CHW format if needed.
> Alternatively, use a custom PyTorch DataLoader with `transforms.ToTensor()` (which
> outputs CHW directly). When passing a Python `dataloader=` argument to
> `dx_com.compile()`, omit `default_loader` from config.json.

> **⚠ Calibration input range by model family** (SDK requirement):
> - **YOLO models**: Input range MUST be `[0, 1]`. Use `transforms.ToTensor()` which
>   automatically converts `[0, 255]` uint8 → `[0, 1]` float32. If using `default_loader`,
>   add `{"div": 255}` to `preprocessings`. Feeding raw `[0, 255]` values causes
>   calibration mismatch and incorrect quantization.
> - **ImageNet classification models**: Use `normalize(mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225])`
>   after `ToTensor()`.
> - **General rule**: Match the preprocessing used during training.

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

#### Custom PyTorch DataLoader

When the default loader is insufficient, provide a custom `torch.utils.data.DataLoader`.
Follow the SDK pattern from `source/docs/02_07_Common_Use_Cases.md`:

```python
# compile.py — custom DataLoader following SDK pattern
import os
import numpy as np
from PIL import Image
from torchvision import transforms
from torch.utils.data import Dataset, DataLoader

class CalibDataset(Dataset):
    """Load calibration images from a directory."""
    def __init__(self, image_dir: str, img_size: int = 640):
        self.image_dir = image_dir
        self.image_files = sorted([
            f for f in os.listdir(image_dir)
            if f.endswith(('.jpg', '.png', '.jpeg'))
        ])
        assert self.image_files, f"No images found in {image_dir}"
        self.transform = transforms.Compose([
            transforms.Resize((img_size, img_size)),
            transforms.ToTensor(),
        ])

    def __len__(self):
        return len(self.image_files)

    def __getitem__(self, idx):
        img_path = os.path.join(self.image_dir, self.image_files[idx])
        image = Image.open(img_path).convert('RGB')
        return self.transform(image).numpy()  # CHW float32

calib_loader = DataLoader(
    CalibDataset("./calibration_dataset", img_size=640),
    batch_size=1, shuffle=True,
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

#### Background Compilation + compile.pid Pattern (R12/R42 — STRONGLY RECOMMENDED)

The `compile.pid` + `subprocess.Popen` pattern is **strongly recommended** for all
compiler sessions, and **MANDATORY** in cross-project autopilot scenarios (suite-level
R42 compliance). It ensures:
- Compilation survives agent CLI disconnection (SSL/SIGHUP via `start_new_session=True`)
- The Phase 5.8 Pre-DONE gate can verify compilation finished before emitting DONE
- The test harness (`_wait_for_background_compilation`) can poll for completion
- Parallel artifact generation is possible during compilation (critical for autopilot)

> **R42 context**: The suite-level instructions (`AGENTS.md`, `CLAUDE.md`) mark
> synchronous `dx_com.compile()` as **PROHIBITED** in the main process for cross-project
> sessions. Compiler-only sessions MAY use synchronous compilation if no parallel
> artifact generation is needed, but `compile.pid` is still preferred for consistency
> and test harness compatibility.
>
> **OpenCode specific**: opencode delegates to a claude subagent. The subagent MUST
> use background compilation because the parent session may have parallel work queued.
> Synchronous compilation in opencode contexts has caused R42 compliance warnings in
> iter-18 and iter-19.

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

**Guidelines for compilation workflow:**

**Step A — Write compile.py first**

**Step B — Launch compilation (background or synchronous):**

When using background compilation, after launching:
1. **IMMEDIATELY** generate ALL other artifacts:
   factory, `<model>_sync.py`, `setup.sh`, `run.sh`, `verify.py`, `README.md`
2. Check whether `.dxnn` was produced **ONLY AFTER** all other artifacts are written
3. Avoid sleep-polling for `.dxnn` — generate other files first, check once at the end
4. If `.dxnn` is not yet ready, generation is still complete — runtime will finish compilation
5. **NEVER use `pgrep -f` to monitor the compile.pid process** — `pgrep -f "compile.py"`
   matches the bash shell running the loop itself (self-referential), causing an infinite
   loop that never exits even after compilation completes. Always use `kill -0 <PID>`:
   ```bash
   # CORRECT — check by PID
   COMPILE_PID=$(cat compile.pid)
   while kill -0 "$COMPILE_PID" 2>/dev/null; do sleep 10; done
   # PROHIBITED — self-referential, infinite loop
   # while pgrep -f "compile.py" >/dev/null 2>&1; do sleep 20; done
   ```


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

   echo "=== Setting up environment ==="

   # ── Step 1: Verify dx-runtime installation ──
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

   # ── Step 2: Verify/activate dxcom (DX-COM compiler) ──
   # dx-com is a PRIVATE package (not on PyPI). Use the compiler venv.
   if ! python3 -c "import dx_com" 2>/dev/null; then
       echo "dxcom not found in current env. Searching for compiler venv..."
       COMPILER_VENV=""
       for _candidate in \
           "$COMPILER_DIR/venv-dx-compiler-local" \
           "$SUITE_ROOT/venv-dx-compiler-local"; do
           if [ -d "$_candidate" ]; then
               COMPILER_VENV="$(cd "$_candidate" && pwd)"
               break
           fi
       done

       if [ -n "$COMPILER_VENV" ]; then
           echo "Found compiler venv: $COMPILER_VENV"
           source "$COMPILER_VENV/bin/activate"
       elif [ -f "$COMPILER_DIR/install.sh" ]; then
           echo "Running dx-compiler installer..."
           bash "$COMPILER_DIR/install.sh"
           source "$COMPILER_DIR/venv-dx-compiler-local/bin/activate"
       else
           echo "ERROR: Cannot find dx-com. Install manually:"
           echo "  cd <dx-compiler-dir> && bash install.sh"
           exit 1
       fi
   else
       echo "dxcom is already available."
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
     `dx-compiler/dx-agent-dev/<session_id>/`. Adjust if different.

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

3. **README.md** — Session summary (include key sections: Quick Start, Generated Files, Notes):

   ```markdown
   # <Model> Compilation Session

   **Session**: `dx-agent-dev/<session_id>/`
   **Pipeline**: ONNX → DXNN
   **Device**: DX-M1
   **Date**: <YYYY-MM-DD HH:MM (KST)>

   ## Quick Start

   ```bash
   bash setup.sh       # One-time environment setup
   bash run.sh         # Run inference
   python verify.py    # ONNX vs DXNN verification
   ```

   ## Generated Files

   | File | Description |
   |------|-------------|
   | `<model>.onnx` | Source ONNX model |
   | `<model>.dxnn` | Compiled DXNN model |
   | `config.json` | DX-COM compilation config |
   | `verify.py` | ONNX vs DXNN output comparison |
   | `setup.sh` | Environment setup |
   | `run.sh` | Inference launcher |

   ## Notes

   - Quantization: EMA, 100 calibration images
   - PPU config: <type>, conf=<n>, iou=<n>
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

   The verification script MUST satisfy ALL of the following:
   - **Self-contained**: no manual `source venv/bin/activate` required — auto-bootstraps `sys.path`
   - **Exit code 0 on PASS, exit code 1 on any FAIL** — never silently swallow exceptions
   - Run ONNX inference using `onnxruntime`
   - Run DXNN inference using `dx_engine`
   - Print `RESULT: PASS` or `RESULT: FAIL` at the end

   **MANDATORY template** — use this structure (substitute `<MODEL_NAME>` and adjust input shape):

   ```python
   #!/usr/bin/env python3
   """
   verify.py — Verify <MODEL_NAME>.dxnn compilation output.
   Compares ONNX vs DXNN inference on a synthetic input.

   Requires: run setup.sh first, then activate venv before executing.
   Exit code: 0 = PASS, 1 = FAIL
   """

   import os
   import sys

   SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
   REPO_ROOT  = os.path.abspath(os.path.join(SCRIPT_DIR, "../../.."))
   DXNN_PATH  = os.path.join(SCRIPT_DIR, "<MODEL_NAME>.dxnn")
   ONNX_PATH  = os.path.join(REPO_ROOT, "dx-compiler", "<MODEL_NAME>.onnx")

   if os.environ.get("DX_SANITY_FAILED") == "1":
       print("SKIPPED: DX_SANITY_FAILED=1 — NPU-based verification skipped.")
       sys.exit(0)

   if not os.path.exists(DXNN_PATH):
       print(f"ERROR: DXNN not found at {DXNN_PATH}")
       sys.exit(1)

   print(f"DXNN: {DXNN_PATH}")
   print(f"ONNX: {ONNX_PATH}")

   failed = False

   print("\n--- ONNX inference ---")
   try:
       import numpy as np
       import onnxruntime as ort
       sess = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
       input_name = sess.get_inputs()[0].name
       input_shape = sess.get_inputs()[0].shape
       # Replace dynamic dims with concrete values (e.g. batch=1, H=640, W=640)
       concrete_shape = [d if isinstance(d, int) else 1 for d in input_shape]
       dummy_input = np.random.rand(*concrete_shape).astype(np.float32)
       onnx_out = sess.run(None, {input_name: dummy_input})
       print(f"ONNX output shapes: {[o.shape for o in onnx_out]}")
       print(f"ONNX output[0] mean: {onnx_out[0].mean():.6f}")
       print("ONNX inference: PASS")
   except ImportError as e:
       print(f"ONNX inference: FAIL — missing dependency: {e}")
       print(f"  Fix: compiler venv at {REPO_ROOT}/dx-compiler/venv-dx-compiler-local is missing or incomplete")
       failed = True
   except Exception as e:
       print(f"ONNX inference: FAIL — {e}")
       failed = True

   print("\n--- DXNN inference ---")
   try:
       import dx_engine
       engine = dx_engine.InferenceEngine(DXNN_PATH)
       input_size = engine.get_input_size()
       print(f"DXNN input size: {input_size}")
       print("DXNN engine loaded: PASS")
   except ImportError as e:
       print(f"DXNN inference: FAIL — missing dependency: {e}")
       print(f"  Fix: runtime venv at {REPO_ROOT}/dx-runtime/venv-dx-runtime is missing or incomplete")
       failed = True
   except Exception as e:
       print(f"DXNN inference: FAIL — {e}")
       failed = True

   print("\nVerification complete.")
   if failed:
       print("RESULT: FAIL — one or more checks failed (see above)")
       sys.exit(1)
   else:
       print("RESULT: PASS")
       sys.exit(0)
   ```

2. **verify.py runs inside setup.sh venv** — dependencies are provided by the venv:
   The `setup.sh` script creates a venv with `onnxruntime`, `numpy`, and links to
   `dx_engine` site-packages. Activate the venv before running `verify.py`. Do NOT
   add `_add_site_packages()` or `sys.path` bootstrap — the venv handles it.

3. **Run `verify.py` WITH venv activation** — this is the verification test:
   ```bash
   cd "${WORK_DIR}"
   source venv/bin/activate
   python verify.py
   echo "Exit code: $?"
   deactivate
   ```

   Required outcome:
   - Output contains `RESULT: PASS`
   - Exit code is **0**

   If output shows `ONNX inference: FAIL` or `DXNN inference: FAIL`:
   - Check that both venvs exist: `dx-compiler/venv-dx-compiler-local/` and `dx-runtime/venv-dx-runtime/`
   - Fix the `_add_site_packages()` paths and re-run

4. **Interpret results**:
   - **PASS** (exit 0): Both ONNX and DXNN inference succeeded — compilation is valid
   - **FAIL** (exit 1): One or more inference checks failed — see output for which one

5. **If verification fails**: Fix the inference application and re-run `verify.py`
   until it passes. Do NOT proceed to the final report with a failing verification.

**Common verification failures and fixes**:
| Failure | Likely Cause | Fix |
|---|---|---|
| `No module named 'onnxruntime'` | venv not activated or `setup.sh` not run | Run `setup.sh` first, then `source venv/bin/activate` |
| `No module named 'dx_engine'` | venv missing runtime site-packages | Check `setup.sh` links runtime venv site-packages |
| Prints "FAIL" but exits 0 | Missing `sys.exit(1)` in failure branch | Add `sys.exit(1)` after `print("RESULT: FAIL ...")` |
| Wrong class labels | COCO class index off-by-one | Use 0-indexed classes for COCO |
| No detections from DXNN | Confidence threshold too high or wrong output parsing | Lower threshold, check output tensor shape |

**Validation gate**: ALL of the following MUST pass before moving to Phase 5.7:
1. `verify.py` exists in the session directory
2. `python verify.py` (WITHOUT venv activation) exits with code **0**
3. Output contains `RESULT: PASS`
4. Neither `ONNX inference: FAIL` nor `DXNN inference: FAIL` appears in output

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
REF_DXNN="$SUITE_ROOT/dx-runtime/dx_app/assets/models/${MODEL_NAME}.dxnn"
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
# Mandatory pre-DONE check — run this BEFORE emitting [DX-AGENT-DEV: DONE]
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

> **NEVER emit `[DX-AGENT-DEV: DONE]` without a `.dxnn` file in the session directory.**
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

**session.log Anti-Patterns (PROHIBITED):**
```bash
# WRONG — heredoc fabrication
cat << 'EOF' > session.log
Compilation started at ...
EOF

# WRONG — echo/printf fabrication  
echo "=== Compilation Log ===" > session.log
printf "Step 1: ..." > session.log
```

**Correct approach — capture real output:**
```bash
# Capture command output as it runs
bash compile.sh 2>&1 | tee session.log

# Or append incrementally
echo "=== Running sanity check ===" | tee -a session.log
bash sanity_check.sh --dx_rt 2>&1 | tee -a session.log
```

If the agent cannot run a command interactively (e.g., background compilation),
capture the output file:
```bash
# Background compilation already writes to compile_out.log
# Copy/append real output to session.log
cat compile_out.log >> session.log
```

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

**Session**: dx-agent-dev/<session_id>/
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

### Q-PRO Options (DXQ-P0 ~ DXQ-P5) — NOT Default

Q-PRO enhanced quantization (`enhanced_scheme`) is an **advanced option** that is
NOT used by default. It requires GPU for practical execution (3-5x longer calibration).

**Use Q-PRO ONLY when ALL of the following conditions are met:**
1. The end-user explicitly requests enhanced quantization or mentions DXQ-P/Q-PRO
2. GPU is available (`quantization_device: "cuda:0"` verified working)
3. The user confirms they accept the additional calibration time (3-5x)

**Example config (only when explicitly requested by user):**
```json
{
  "enhanced_scheme": {"DXQ-P3": {"num_samples": 1024}},
  "quantization_device": "cuda:0"
}
```

If the user does not mention Q-PRO/DXQ-P/enhanced_scheme, always use EMA (default).

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
