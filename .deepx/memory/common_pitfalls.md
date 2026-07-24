# Common Pitfalls — dx-compiler

> Domain-tagged pitfalls for DEEPX DX-COM compilation workflows.
> Read this file before every compilation task and when errors occur.

---

## 1. [UNIVERSAL] Batch Size Must Be 1

**Symptom**: Compilation fails with shape mismatch error or runtime error
on DEEPX NPU. Error message may reference unexpected batch dimension.

**Cause**: DEEPX NPU hardware requires batch size of exactly 1. Models
exported with batch > 1 or dynamic batch dimension cannot be compiled.

**Fix**:
- When exporting from PyTorch: `dummy_input = torch.randn(1, 3, H, W)`
- In config.json: first dimension of input shape must be `1`
- In ONNX model: verify with:
  ```python
  for inp in model.graph.input:
      shape = [d.dim_value for d in inp.type.tensor_type.shape.dim]
      assert shape[0] == 1
  ```
- If model has batch > 1, re-export with batch=1

---

## 2. [DX_COMPILER] config.json Inputs Key Must Match ONNX Input Name

**Symptom**: Compilation fails immediately with "input not found" or
"key mismatch" error. DX-COM cannot locate the input tensor.

**Cause**: The key in `"inputs"` of config.json does not exactly match
the input node name in the ONNX model graph. This is case-sensitive
and whitespace-sensitive.

**Fix**:
- Inspect ONNX model for exact input name:
  ```python
  import onnx
  model = onnx.load("model.onnx")
  print(model.graph.input[0].name)  # e.g., "images" not "input"
  ```
- Update config.json to use the exact name:
  ```json
  {"inputs": {"images": [1, 3, 640, 640]}}
  ```
- Common mismatches: `"input"` vs `"images"`, `"input.1"` vs `"input_1"`,
  `"data"` vs `"input"`
- After onnx-simplifier, input names may change — always re-check (see Pitfall #9)

---

## 3. [QUANTIZATION] Calibration Data Must Be Representative

**Symptom**: Compiled model produces poor accuracy or unexpected outputs
despite successful compilation. Quantization ranges are incorrect.

**Cause**: Calibration images are not representative of actual inference
data. Using random images, synthetic data, or images from a different
domain causes incorrect quantization range estimation.

**Fix**:
- Use images from the same distribution as inference data
- For COCO models: use COCO val2017 images for calibration
- For custom models: use a subset of the training/validation set
- Minimum 100 images (default `calibration_num`)
- Ensure variety: include different lighting, angles, object sizes
- Avoid duplicate or near-duplicate images
- Verify file extensions in config match actual files:
  ```json
  {"file_extensions": ["jpeg", "png", "jpg"]}
  ```

---

## 4. [DX_COMPILER] Dynamic Shapes Not Supported

**Symptom**: Compilation fails with "dynamic dimension" or "undefined
shape" error. ONNX model has -1 or 0 in dimension values.

**Cause**: DEEPX NPU requires fully static shapes. ONNX models exported
with `dynamic_axes` parameter or containing data-dependent shapes cannot
be compiled.

**Fix**:
- When exporting from PyTorch, do NOT use `dynamic_axes`:
  ```python
  # Wrong
  torch.onnx.export(model, dummy, "m.onnx", dynamic_axes={"input": {0: "batch"}})

  # Correct
  torch.onnx.export(model, dummy, "m.onnx")  # No dynamic_axes
  ```
- Verify all dimensions are positive integers:
  ```python
  for inp in model.graph.input:
      for dim in inp.type.tensor_type.shape.dim:
          assert dim.dim_value > 0, f"Dynamic dim found: {dim}"
  ```
- If model requires different sizes, compile separate .dxnn for each size
- Running onnx-simplifier may resolve some symbolic dimensions (but do NOT run automatically — see Pitfall #9)

---

## 5. [UNIVERSAL] ONNX Opset Version Must Be 11-21

**Symptom**: Compilation fails with "unsupported opset" error or
unexpected operator failures.

**Cause**: DX-COM v2.2.1 supports ONNX opset versions 11 through 21.
Models exported with opset < 11 or > 21 are not supported.

**Fix**:
- Check current opset:
  ```python
  import onnx
  model = onnx.load("model.onnx")
  print(model.opset_import[0].version)
  ```
- Re-export with supported opset (13 recommended):
  ```python
  torch.onnx.export(model, dummy, "m.onnx", opset_version=13)
  ```
- If converting from another framework, use onnx version converter:
  ```python
  from onnx import version_converter
  new_model = version_converter.convert_version(model, 13)
  ```
- Opset 13 is recommended as the best balance of compatibility and features

---

## 6. [DX_COMPILER] PPU Type Mismatch — Anchor-Based vs Anchor-Free

**Symptom**: Detection model compiles successfully but produces incorrect
bounding boxes, NaN confidence scores, or zero detections at inference.

**Cause**: Wrong PPU type configured for the detection model architecture.
Anchor-based models (YOLOv3/v4/v5/v7) use type 0 with anchor definitions.
Anchor-free models (YOLOX, YOLOv8-v12) use type 1 without anchors.

**Fix**:
- Identify model architecture from the model name or documentation
- Set correct PPU type:
  - **Type 0** (anchor-based): YOLOv3, YOLOv4, YOLOv5, YOLOv7
    ```json
    {"ppu": {"type": 0, "anchors": [[...], [...], [...]]}}
    ```
  - **Type 1** (anchor-free): YOLOX, YOLOv8, YOLOv9, YOLOv10, YOLOv11, YOLOv12
    ```json
    {"ppu": {"type": 1}}
    ```
- For anchor-based models, ensure anchors match the model's training config
- Common mistake: using YOLOv5 anchors with YOLOv8 (different architecture)
- When in doubt, check the model's original training configuration

---

## 7. [DX_COMPILER] Absolute Calibration Paths Break Portability

**Symptom**: Compilation fails on a different machine, or config.json references
a path that does not exist. The `dataset_path` field points to an absolute path
like `/data/home/user/calibration/` that only exists on one system.

**Cause**: Using absolute paths in config.json for `dataset_path` makes the
configuration non-portable. When the project is shared, cloned, or moved to
a different directory, the path breaks.

**Fix**:
- Always use relative paths in config.json: `"dataset_path": "./calibration_dataset"`
- Create a symlink in the working directory pointing to the actual data:
  ```bash
  ln -sf ../../dx_com/calibration_dataset dx-agent-dev/<session_id>/calibration_dataset
  ```
- Run `dxcom` from the working directory so the relative path resolves correctly:
  ```bash
  cd dx-agent-dev/<session_id>/
  dxcom -m model.onnx -c config.json -o ./
  ```
- The calibration data chain: `working_dir/calibration_dataset` → `dx_com/calibration_dataset/`

---

## 8. [DX_COMPILER] Output Files Scattered Across Directories

**Symptom**: After compilation, output files (ONNX, config.json, .dxnn, logs)
are spread across multiple directories. Difficult to find or reproduce results.

**Cause**: Not using a dedicated session working directory. Files saved to
current directory, various `output/` paths, or project root.

**Fix**:
- Always create a session working directory: `dx-agent-dev/<session_id>/`
- Session ID format: `YYYYMMDD-HHMMSS_<agent>_<model>_<task>` (local timezone)
- Save ALL artifacts (ONNX, config.json, .dxnn, compiler.log) to this directory
- At the end, generate a report listing all files with sizes
- Example:
  ```bash
  SESSION_ID="$(date +%Y%m%d-%H%M%S)_yolo26x_pt_to_dxnn"  # local timezone (NOT UTC)
  WORK_DIR="dx-agent-dev/${SESSION_ID}"
  mkdir -p "${WORK_DIR}"
   # All subsequent operations use ${WORK_DIR}/
   ```

---

## 9. [UNIVERSAL] Do NOT Auto-Run onnx-simplifier

**Symptom**: Agent automatically runs `onnx-simplifier` during PT → ONNX
conversion, producing a `_sim.onnx` file that the user did not request.
Subsequent compilation uses the simplified model, which may have subtle
differences from the original export.

**Cause**: Workflow instructions previously said "always simplify before
compilation." This is incorrect — simplification should only be performed
when the user explicitly requests it.

**Risks of automatic simplification**:
1. **Numerical precision loss**: Constant folding during simplification may
   introduce FP32 rounding errors that accumulate through the network
2. **Debugging difficulty**: Original PyTorch layer and node names are
   altered or merged, making it much harder to trace issues back to the
   source model layers
3. **Model breakage**: Models with complex control flow, custom operators,
   or unusual graph patterns may produce incorrect simplified graphs or
   fail entirely during the simplification process
4. **Input name changes**: The simplifier may rename input nodes (e.g.,
   `images` → `input.1`), causing mismatches with the `inputs` key in
   config.json and silent compilation failures

**Fix**:
- NEVER run `onnx-simplifier`, `onnxsim.simplify()`, or
  `python -m onnxsim` unless the user explicitly requests it
- The default workflow is: Export → Validate → Compile (no simplification)
- If the user requests simplification, always re-verify input names after:
  ```python
  original_name = original_model.graph.input[0].name
  simplified_name = simplified_model.graph.input[0].name
  if original_name != simplified_name:
      print(f"WARNING: Input name changed: {original_name} → {simplified_name}")
  ```
- If simplification fails, proceed with the unsimplified model

---

## 10. [UNIVERSAL] Ultralytics YOLO Multi-Output ONNX Export

**Symptom**: ONNX model exported from Ultralytics YOLO (v8/v9/v10/v11/v12/v26)
has 6 output nodes instead of 1. Downstream compilation or inference fails with
shape-related errors (e.g., `ValueError` in postprocessor when trying to find
DFL tensors, empty `reg_list`, or `concatenate` errors on zero-length arrays).

**Cause**: When using `torch.onnx.export()` manually on an Ultralytics model,
the `Detect` head's `export` attribute defaults to `False`. In non-export mode,
`Detect.forward()` returns `(y, preds)` — a tuple containing the inference
tensor and the raw predictions dict. During ONNX tracing, this tuple is flattened
into 6 separate output tensors (3 from one2many branch + 3 from one2one branch,
or similar depending on model version).

The official Ultralytics exporter (`model.export()`) internally sets
`model.model[-1].export = True` on all detection heads, which causes
`forward()` to return only the single inference tensor `y`.

Additionally, the `end2end` property (controlled by `_end2end` attribute)
determines the output shape:
- `end2end=True` + `export=True` → `[1, 300, 6]` (NMS built-in, single tensor)
- `end2end=False` + `export=True` → `[1, 84, 8400]` (fused output, single tensor)
- `export=False` (any `end2end`) → `(y, preds)` tuple → **6 ONNX outputs (BUG)**

**Fix — Option A (Recommended): Use the Official Export API**:
```python
from ultralytics import YOLO
model = YOLO("yolo26x.pt")
model.export(format="onnx", opset=13, imgsz=640, simplify=False)
# Produces a single-output ONNX automatically
```

**Fix — Option B: Manual `torch.onnx.export()` with Proper Flags**:
```python
from ultralytics import YOLO
model = YOLO("yolo26x.pt").model
model.eval()

# CRITICAL: Set export flag on all Detect/Segment/Pose heads
for m in model.modules():
    if hasattr(m, "export"):
        m.export = True
    if hasattr(m, "_end2end"):
        m._end2end = False  # Set False for [1, 84, 8400] fused output
        # Set True for [1, 300, 6] NMS-free output
        # Recommended: True for NMS-free models (YOLOv10, YOLO26),
        #              False for optional NMS-free models (YOLOv8, v9, v11, v12)

dummy = torch.randn(1, 3, 640, 640)
torch.onnx.export(model, dummy, "model.onnx", opset_version=13,
                   input_names=["images"], output_names=["output0"])
```

**Fix — Option C: ModelWrapper to Extract First Output**:
```python
class ModelWrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    def forward(self, x):
        return self.model(x)[0]  # Only first output

wrapper = ModelWrapper(model)
torch.onnx.export(wrapper, dummy, "model.onnx", ...)
```

**Post-Export Verification** (MANDATORY after any Ultralytics export):
```python
import onnx
model = onnx.load("model.onnx")
num_outputs = len(model.graph.output)
assert num_outputs == 1, f"Expected 1 output, got {num_outputs}. Set Detect.export=True."
print(f"Output: {model.graph.output[0].name}, "
      f"shape: {[d.dim_value for d in model.graph.output[0].type.tensor_type.shape.dim]}")
```

**Impact of `end2end` on Postprocessing**:
| `end2end` | Output Shape | Postprocessing Required |
|---|---|---|
| `True` | `[1, 300, 6]` | None — NMS built-in, output is `[x1,y1,x2,y2,conf,cls]` |
| `False` | `[1, 84, 8400]` | Standard YOLO decode: split boxes/scores, apply NMS |

**Recommended `end2end` value by model type**:
| Model Type | NMS-Free | Recommended `end2end` | Rationale |
|---|---|---|---|
| YOLOv10, YOLO26 | Yes (native) | `True` | Native one-to-one matching; `False` adds unnecessary NMS |
| YOLOv8, v9, v11, v12 | Optional | `False` | Full NMS control, no 300 detection cap |
| YOLOv3, v4, v5, v7, YOLOX | No | N/A | `end2end` not applicable |

Choose based on your deployment needs. For NMS-free models, `end2end=True` uses the
model's native architecture. For optional NMS-free models, `end2end=False` gives full
control over NMS parameters.

---

## 11. [UNIVERSAL] Missing Deployment Artifacts — setup.sh, run.sh, README.md

**Symptom**: After compilation, the user receives a `.dxnn` model and a
`detect_*.py` inference script, but cannot run it because there is no
virtual environment, no `dx_engine` installed, and no documentation
explaining how to set up and run the application.

**Cause**: The agent generated only the model and inference code but did not
create the deployment artifacts needed to actually run the application.
The user must manually figure out venv creation, dx_engine wheel location,
pip dependencies, and command-line arguments.

**Fix**:
- **ALWAYS** generate these mandatory files in the session directory:
  1. `setup.sh` — Checks dx-runtime installation via
     `dx-runtime/scripts/sanity_check.sh --dx_rt`, installs missing components
     via `dx-runtime/install.sh --all --exclude-app --exclude-stream`;
     checks dxcom availability, installs via `dx-compiler/install.sh` if missing;
     creates venv (**MANDATORY** — PEP 668 on Ubuntu 24.04+), installs dx_engine from
     `dx-runtime/dx_rt/python_package/*.whl`, installs `opencv-python`,
     `numpy`, and `onnxruntime`
  2. `run.sh` — One-command inference launcher with venv activation check
     and example paths to sample images from `dx-runtime/dx_app/sample/img/`
  3. `README.md` — Session summary with quick start, generated files
     table, environment info, and verification results
  4. `verify.py` — ONNX vs DXNN comparison script (see Pitfall #12)
  5. `session.log` — **Actual command execution output** captured via `tee`
     (NOT a hand-written summary — see below)
- The user should be able to run `bash setup.sh && bash run.sh` immediately
  after compilation with zero manual setup

**session.log must contain real output, NOT summaries**:
- Append each command and its actual output to `session.log` immediately after
  execution — do NOT wait until the end of the session
- In agent/copilot environments (where each command is a separate tool call),
  append the command line and output after each tool call returns:
  ```bash
  echo "$(date '+%H:%M:%S') $ <command>" >> "${WORK_DIR}/session.log"
  echo "<actual output>" >> "${WORK_DIR}/session.log"
  ```
- NEVER write a `cat << 'EOF'` block with curated summaries at the end
- The log should show exact command output as it appeared in the terminal

---

## 12. [UNIVERSAL] Postprocessing Bugs in Generated Inference Code

**Symptom**: Compiled DXNN model benchmarks correctly (e.g., 139 FPS via
`run_model`) but the generated inference application produces wrong results:
- Wrong class labels (e.g., dog detected as elephant)
- Very few or zero detections on images that should have many
- Bounding boxes in wrong positions or with wrong sizes
- All detections assigned to the same class

**Cause**: The inference application's postprocessing code has bugs. The
model itself is fine — the problem is in how the generated Python code
interprets the model's output tensors. Common issues:

1. **Class index off-by-one**: COCO classes are 0-indexed (0=person, ...,
   79=toothbrush) but the code uses 1-indexed or a wrong label mapping
2. **Bbox format mismatch**: Model outputs center-xywh but code expects
   xyxy, or vice versa. Missing denormalization (output in 0-1 range but
   code expects pixel coordinates)
3. **Confidence threshold applied incorrectly**: Threshold applied before
   NMS when it should be after, or using objectness score instead of
   class confidence
4. **Output tensor shape misparsing**: For `[1, 84, 8400]` output,
   dimensions 0-3 are bbox coords and 4-83 are class scores. Code may
   transpose or index incorrectly
5. **NMS-free vs fused output confusion**: `end2end=True` output
   `[1, 300, 6]` is `[x1,y1,x2,y2,conf,cls]` — needs no NMS. But
   `end2end=False` output `[1, 84, 8400]` needs decode + NMS

**Fix**:
- **ALWAYS** generate `verify.py` alongside the inference application
- `verify.py` runs the ONNX model (via `onnxruntime`) and the DXNN model
  (via `dx_engine`) on the same sample image with identical postprocessing
- Compare detection count (within 20%), class labels, and bbox IoU
- Use sample images from `dx-runtime/dx_app/sample/` — choose based on
  model task type:
  - Object Detection: `img/sample_dog.jpg`, `img/sample_horse.jpg`
  - Face Detection: `img/sample_face.jpg`, `img/sample_crowd.jpg`
  - Pose Estimation: `img/sample_people.jpg`, `img/sample_crowd.jpg`
  - Hand Detection: `img/sample_hand.jpg`
  - OBB: `dota8_test/P0177.png`, `dota8_test/P0284.png`
  - Segmentation: `img/sample_street.jpg`, `img/sample_parking.jpg`
  - Classification: `ILSVRC2012/0.jpeg`, `ILSVRC2012/1.jpeg`
  - Super Resolution: `img/sample_superresolution.png`
  - Low-light: `img/sample_lowlight.jpg`, `img/sample_dark_room.jpg`
  - Denoising: `img/sample_denoising.jpg`
- **Run `verify.py` before presenting results to the user**
- If verification fails, debug postprocessing and re-verify until PASS
- Never present a "successful compilation" report when verify.py fails

**Verification checklist**:
```python
# For YOLO [1, 84, 8400] fused output:
# - Transpose to [8400, 84]
# - First 4 values: cx, cy, w, h (center-format, pixel coords)
# - Values 4-83: class confidence scores (no objectness in v8+)
# - Convert cx,cy,w,h → x1,y1,x2,y2
# - Apply confidence threshold
# - Run NMS

# For YOLO [1, 300, 6] end2end output:
# - Each row: [x1, y1, x2, y2, confidence, class_id]
# - Already NMS'd — just filter by confidence
# - Coordinates are in pixel space
```

---

## 13. [DX_COMPILER] ONNX Runtime vs DX Engine Preprocessing Mismatch

**Symptom**: `verify.py` comparison fails even though both ONNX and DXNN
models are correct. Detections differ significantly between the two.

**Cause**: Different preprocessing applied to the input image for ONNX
runtime vs dx_engine inference. Common differences:
- RGB vs BGR channel order
- Different resize interpolation methods
- Different normalization (0-255 vs 0-1 range)
- Different padding behavior (letterbox vs stretch)

**Fix**:
- In `verify.py`, use EXACTLY the same preprocessing function for both
  ONNX and DXNN inference paths
- Extract the preprocessing into a shared function:
  ```python
  def preprocess(image_path, input_size=(640, 640)):
      img = cv2.imread(image_path)
      img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
      img = cv2.resize(img, input_size)
      img = img.astype(np.float32) / 255.0
      img = np.transpose(img, (2, 0, 1))  # HWC → CHW
      img = np.expand_dims(img, 0)  # Add batch dim
      return img
  ```
- Call this same function for both inference paths
- If dx_engine has its own built-in preprocessing, disable it and use
  the shared function instead

---

## 14. [DX_COMPILER] YOLO26 Does Not Support PPU Compilation

**Symptom**: Agent offers PPU compilation option for YOLO26 models, or user
requests PPU for YOLO26 and gets unexpected compilation results.

**Cause**: YOLO26 is not in the official dxcom PPU supported model list.
The PPU hardware supports confidence filtering and argmax — but YOLO26 with
`end2end=True` already performs these operations internally (NMS-free native
architecture with output `[1, 300, 6]`).

**Official PPU supported models** (per `02_05_JSON_File_Configuration.md`):
- Type 0 (anchor-based): YOLOv3, YOLOv4, YOLOv5, YOLOv7
- Type 1 (anchor-free): YOLOX, YOLOv8, YOLOv9, YOLOv10, YOLOv11, YOLOv12

**Fix**:
- Skip brainstorming Q3 (PPU question) for YOLO26 models
- If user explicitly asks for PPU with YOLO26, explain that PPU is redundant
  because YOLO26's end2end output already includes confidence filtering and
  class prediction
- Recommend `end2end=True` export instead, which provides similar benefits
  (ready-to-use detections) without PPU

---

## 15. [UNIVERSAL] Never Reuse Previous Session Artifacts

**Symptom**: Agent checks `dx-agent-dev/` for existing sessions, finds a
previous run with the same model (e.g., `20260408-113623_yolo26n_onnx_to_dxnn`),
and skips the model download/export step by reusing the existing `.onnx` file.
The user expects a fresh end-to-end run but gets a partial one.

**Cause**: The agent tries to be "efficient" by avoiding redundant work. It runs
`ls dx-agent-dev/` or similar commands to scan for prior sessions, detects an
existing ONNX or DXNN file, and decides to reuse it instead of re-downloading
and re-exporting.

**Why this is wrong**:
1. **Reproducibility**: Each session must be independently reproducible with its
   own artifacts. Reusing files from a prior session creates hidden dependencies.
2. **Stale artifacts**: The previous ONNX may have been exported with different
   settings (different `end2end`, different opset, different input size).
3. **Incomplete sessions**: The previous session may have failed partway through,
   leaving a broken or partial ONNX file.
4. **User expectation**: When users say "compile model X", they expect the full
   pipeline from scratch, not a shortcut.

**Fix**:
- **NEVER** run `ls dx-agent-dev/`, `find dx-agent-dev/`, or any command
  that checks for existing sessions or artifacts from previous runs
- **ALWAYS** create a new session directory with a fresh `$(date +%Y%m%d-%H%M%S)` (local timezone)
  timestamp
- **ALWAYS** re-download, re-export, and re-compile the model from scratch
- The only files that may be shared across sessions are the calibration dataset
  at `dx_com/calibration_dataset/` (via symlink) and example scripts in `example/`

---

## 16. [UNIVERSAL] PEP 668 — pip install Fails Without venv on Ubuntu 24.04+

**Symptom**: Generated `setup.sh` runs `pip install opencv-python numpy onnxruntime`
but fails with:

```
error: externally-managed-environment

× This environment is externally managed
╰─> To install Python packages system-wide, try apt install python3-xyz.
    If you wish to install a non-Debian-packaged Python package,
    create a virtual environment using, e.g.:
        python3 -m venv path/to/venv
```

**Cause**: Ubuntu 24.04+ (and other recent distros) implement PEP 668, which
marks the system Python as "externally managed" and blocks `pip install` outside
a virtual environment. The generated `setup.sh` calls `pip install` without
first creating or activating a venv.

**Fix**:
- **ALWAYS** create and activate a venv in `setup.sh` before any `pip install`:
  ```bash
  # MANDATORY venv check — PEP 668 on Ubuntu 24.04+
  if [ -z "${VIRTUAL_ENV:-}" ]; then
      VENV_DIR="${SCRIPT_DIR}/venv"
      if [ ! -d "$VENV_DIR" ]; then
          python3 -m venv "$VENV_DIR"
      fi
      source "$VENV_DIR/bin/activate"
  fi
  ```
- **ALWAYS** check venv activation in `run.sh` before running Python scripts:
  ```bash
  if [ -z "${VIRTUAL_ENV:-}" ]; then
      VENV_DIR="${SCRIPT_DIR}/venv"
      if [ -d "$VENV_DIR" ]; then
          source "$VENV_DIR/bin/activate"
      else
          echo "ERROR: venv not found. Run 'bash setup.sh' first."
          exit 1
      fi
  fi
  ```
- Never use `--break-system-packages` as a workaround — it bypasses OS protections
- The venv check uses `${VIRTUAL_ENV:-}` to detect if already inside a venv
  (set by `source .../bin/activate`)

---

## [DX_COMPILER] Skipping Cross-Validation with Precompiled Reference Model

**Symptom**: verify.py reports FAIL but it is unclear whether the problem is in
the compiled .dxnn model or in verify.py itself. Agent wastes time debugging
compilation parameters when the real issue is a bug in the verification script.

**Cause**: verify.py compares ONNX vs DXNN output, but when the comparison fails,
there is no way to distinguish between a compilation problem and a verify.py bug
without a second reference point.

**Fix**: When a precompiled reference DXNN exists in `dx-runtime/dx_app/assets/models/`
for the same model, run verify.py with BOTH the precompiled and generated models:
```bash
REF_DXNN="$SUITE_ROOT/dx-runtime/dx_app/assets/models/<model>.dxnn"
if [ -f "$REF_DXNN" ]; then
    python verify.py --dxnn "$REF_DXNN"        # Reference
    python verify.py --dxnn <model>.dxnn        # Generated
fi
```

**Decision tree**:
- Both FAIL → verify.py code problem (fix verify.py first)
- Reference PASS, Generated FAIL → compilation problem (fix config, quantization)
- Both PASS → compilation correct

See `dx-dxnn-compiler.md` Phase 5.7 and `dx-agent-compiler-validate.md` Phase 3.5.

---

## 18. [DX_COMPILER] NHWC/NCHW DataLoader Mismatch in CLI Compilation

**Symptom**: `dxcom -m model.onnx -c config.json` fails with:
```
DataLoaderError: Input shape mismatch for input 'input':
dataloader provides torch.Size([1, 360, 640, 3]), but model expects (1, 3, 360, 640).
```

**Cause**: The dxcom CLI's built-in default dataloader loads calibration images
in NHWC format `[1, H, W, C]`. However, many ONNX models (especially those
exported from PyTorch) expect NCHW input `[1, C, H, W]`. The CLI dataloader
does NOT auto-transpose, causing a shape mismatch.

**Fix**: Use the **Python API with a custom torch DataLoader** that produces
NCHW tensors:
```python
import dx_com
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import numpy as np
import torch, os

class CalibDataset(Dataset):
    def __init__(self, image_dir, input_shape):
        # input_shape: NCHW e.g. (1, 3, 360, 640)
        self.files = sorted([
            os.path.join(image_dir, f)
            for f in os.listdir(image_dir)
            if f.lower().endswith(('.jpg', '.jpeg', '.png'))
        ])
        self.h, self.w = input_shape[2], input_shape[3]
    def __len__(self):
        return len(self.files)
    def __getitem__(self, idx):
        img = Image.open(self.files[idx]).convert("RGB")
        img = img.resize((self.w, self.h))
        arr = np.array(img, dtype=np.float32)          # HWC
        arr = np.transpose(arr, (2, 0, 1))             # CHW [C,H,W]
        return torch.from_numpy(arr)                   # CHW — DataLoader adds batch dim automatically

dataset = CalibDataset("./calibration_dataset", (1, 3, 360, 640))
dataloader = DataLoader(dataset, batch_size=1, shuffle=True)
dx_com.compile(model="model.onnx", output_dir=".", dataloader=dataloader,
               calibration_num=100, opt_level=1, gen_log=True)
```

**Key points**:
- CLI `config.json` and Python `dataloader` are **mutually exclusive** — do NOT
  pass both `config=` and `dataloader=` to `dx_com.compile()`
- `ToTensor()` normalizes to [0,1] — if the model expects [0,255], do NOT use it
- Always match the preprocessing to the model's expected input range and format
- The Python API automatically handles the config.json-equivalent settings
  (calibration method, etc.) via function parameters
- **NEVER use `unsqueeze(0)` in `__getitem__`** — PyTorch DataLoader automatically
  adds the batch dimension. Using `unsqueeze(0)` produces shape `[1,1,C,H,W]`
  instead of the expected `[1,C,H,W]`, causing `DataLoaderError: Input shape mismatch`.
  Return CHW tensor `[C,H,W]` from `__getitem__`; DataLoader produces `[N,C,H,W]`.

**Prevention**: Before running `dxcom` CLI, check if the ONNX model input is
NCHW. If yes, prefer the Python API with a custom DataLoader to avoid this issue.

---

## 19. [DX_COMPILER] PEP 668 — System-Wide pip Install Blocked on Ubuntu 24.04+

**Symptom**: `pip install <package>` fails with:
```
error: externally-managed-environment
× This environment is externally managed
```

**Cause**: Ubuntu 24.04+ enforces PEP 668, which prevents system-wide pip
installs to protect the OS Python environment.

**Fix**: Always use a virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install <package>
```

**NEVER use** `--break-system-packages` — this can corrupt the system Python.

**For dxcom**: Use the existing compiler venv if available:
```bash
source dx-compiler/venv-dx-compiler-local/bin/activate
```

**For dx_engine**: Use the dx-runtime venv or create a session-local venv:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install dx-runtime/dx_rt/python_package/dx_engine-*.whl
```

---

## 20. [DX_COMPILER] Compiler Preprocessing Bake-in Changes Input Format — Affects Downstream Demos

**Symptom**: After compilation, the generated demo scripts produce completely
wrong results (garbled output, zero accuracy). The DXNN model itself is correct
— the problem is that demo scripts use preprocessing matched to the original
ONNX input format, not the compiled DXNN input format.

**Cause**: dxcom may bake preprocessing operations into the NPU graph during
compilation. When this happens, the DXNN model's input format differs from
the original ONNX model:

- `Normalize(mean=0, std=1)` inserted → input becomes uint8 (NPU handles float conversion)
- `transpose` skipped → layout stays NHWC (not converted to NCHW)
- `resize` skipped → input must be pre-resized to expected H×W

The compiler log records which preprocessing steps were inserted vs skipped.
The resulting DXNN model expects a different input format than the ONNX model.

**Impact on downstream code**:
- Demo scripts (`demo_dxnn_sync.py`, `demo_dxnn_async.py`, etc.) that use
  ONNX-style preprocessing (NCHW float32) will feed wrong data to the DXNN model
- `verify.py` that compares ONNX vs DXNN must use different preprocessing for each
- `setup.sh` and `run.sh` may need updated usage instructions

**Fix for cross-project tasks (compile + demo generation)**:
When generating demo scripts for a compiled DXNN model, ALWAYS include
auto-detection of the actual input format:

```python
input_info = engine.get_input_tensors_info()
input_shape = input_info[0]["shape"]
# [1, H, W, 3] = NHWC (compiler baked in preprocessing) → no transpose, uint8
# [1, 3, H, W] = NCHW (standard) → transpose + float32 + normalize
```

**Prevention**: After compilation, check the compiler log for preprocessing
bake-in. If bake-in occurred, explicitly note in the session README that the
DXNN input format differs from the ONNX input format. All downstream demo
scripts MUST use `get_input_tensors_info()` to auto-detect the format.
See dx_app `common_pitfalls.md` Pitfall #19 for the complete auto-detect pattern.

**CPU MemoryOps and `DXRT_DYNAMIC_CPU_THREAD=ON`**: When preprocessing ops
are partially baked in (some inserted, some skipped), the skipped ops remain
as CPU MemoryOps in the DXNN graph. These run on a single CPU thread by default
and can bottleneck async pipelines. ALWAYS add `export DXRT_DYNAMIC_CPU_THREAD=ON`
to `run.sh` when skipped preprocessing ops are detected in the compiler log.

**Diagnosis**: Compare `run_model -m model.dxnn -t 5 -v` (NPU+CPU) vs
`run_model -m model.dxnn -t 5 -v --use-ort` (CPU-only). If FPS is similar,
CPU ops are the bottleneck. See dx_app `common_pitfalls.md` Pitfall #21 and
`performance_patterns.md` for the complete diagnosis workflow.

---

## 21. [DX_COMPILER] Never Fabricate dxcom API Calls — Use Toolset Files

**Symptom**: Agent generates dxcom Python code or CLI commands that use
non-existent functions, wrong import paths, or incorrect parameter names.
Compilation fails with `ImportError`, `AttributeError`, or `TypeError`.

**Cause**: The agent attempts to call dxcom from memory without reading the
actual API documentation. Different models (GPT-4.1, etc.) are particularly
prone to fabricating API signatures that look plausible but do not exist.

**Common fabricated patterns**:

| What the agent writes | What actually works |
|---|---|
| `from dxcom import dxcom` | `import dx_com` |
| `dxcom.compile(model_path=..., output=...)` | `dx_com.compile(model=..., output_dir=...)` |
| `dxcom.quantize(...)` | No such function — `dx_com.compile()` handles quantization |
| `dxcom.calibrate(...)` | No such function — calibration is part of `dx_com.compile()` |
| `config.json` with `"model_path"` key | No such key — use `"inputs"` with ONNX input name |
| `config.json` with `"target_device"` key | No such key — device defaults to dx_m1 |
| `config.json` with `"output_format"` key | No such key — output is always .dxnn |

**Fix**:
- **ALWAYS read the toolset files before calling dxcom**:
  - CLI: `.deepx/toolsets/dxcom-cli.md`
  - Python API: `.deepx/toolsets/dxcom-api.md`
  - Config schema: `.deepx/toolsets/config-schema.md`
- **ALWAYS verify dxcom is installed** before any invocation (see Phase -1 in
  `dx-dxnn-compiler.md`)
- **When generating config.json**, read a sample config from
  `dx_com/sample_models/json/*.json` as a reference
- **NEVER generate dxcom calls from memory** — always cross-reference with
  the toolset documentation

**Prevention**: The `dx-dxnn-compiler` agent has a Phase -1 pre-flight check
that verifies dxcom installation before any compilation attempt. The router
agent (`dx-compiler-builder`) also verifies installation before routing.

---

## 22. [DX_COMPILER] Never Modify compiler.properties

**Symptom**: After agent modifies `compiler.properties`, `install.sh` fails
with missing properties, dxcom downloads break, or credentials are corrupted.
In the worst case (session 8b4334a6), the agent overwrote the entire file with
fabricated compiler flags, destroying download URLs and credentials.

**Cause**: The agent encounters a compilation error and, instead of fixing
`config.json` or dxcom arguments, modifies the system-level
`compiler.properties` file. This file is sourced by `install.sh` and
`docker_build.sh` via `source compiler.properties`.

**Actual `compiler.properties` schema** (key=value format, sourced as bash):
```properties
# DX-COM compiler version and download URLs
COM_VERSION=2.2.1

COM_DOWNLOAD_LEGACY_URL=https://developer.deepx.ai/download/?id=...
COM_CP38_DOWNLOAD_URL=https://developer.deepx.ai/download/?id=...
COM_CP39_DOWNLOAD_URL=https://developer.deepx.ai/download/?id=...
COM_CP310_DOWNLOAD_URL=https://developer.deepx.ai/download/?id=...
COM_CP311_DOWNLOAD_URL=https://developer.deepx.ai/download/?id=...
COM_CP312_DOWNLOAD_URL=https://developer.deepx.ai/download/?id=...

# DX-TRON visual inspector version and download URL
TRON_VERSION=2.0.1
TRON_DOWNLOAD_URL=https://developer.deepx.ai/download/?id=...

# Optional: auto-login credentials for DEEPX developer portal
# If set, install.sh uses these instead of prompting for credentials.
DX_USERNAME=<email>
DX_PASSWORD=<password>
```

**Required properties** (validated by `install.sh` `validate_environment()`):
- `COM_VERSION` — must be set
- `COM_CP{38,39,310,311,312}_DOWNLOAD_URL` — Python-version-specific wheel URLs
- `TRON_VERSION` and `TRON_DOWNLOAD_URL` — DX-TRON download info

**Why agents must NEVER modify it**:
1. **Contains credentials**: `DX_USERNAME` and `DX_PASSWORD` are plaintext login
   credentials for the DEEPX developer portal. Modifying or overwriting the file
   destroys these credentials, blocking future installs.
2. **Sourced as bash**: `install.sh` runs `source compiler.properties`. Invalid
   syntax (spaces around `=`, missing quotes, non-bash entries) causes `install.sh`
   to crash or set wrong variables.
3. **Global impact**: Changes affect ALL installations and Docker builds, not just
   the current compilation session.
4. **Not a compiler config**: Despite the name, this file does NOT control compiler
   behavior (optimization, quantization, etc.). It only contains version numbers
   and download URLs. Compilation settings belong in `config.json`.

**Fix**:
- **NEVER write to, edit, or append to `compiler.properties`**
- If compilation fails, the fix is ALWAYS in one of:
  - `config.json` — input names, shapes, calibration settings, PPU config
  - `dxcom` CLI arguments — `--opt_level`, `--aggressive_partitioning`
  - The ONNX model itself — opset version, static shapes, batch size
- If `compiler.properties` is corrupted, restore from git:
  ```bash
  cd dx-compiler && git checkout compiler.properties
  ```
- **This rule has no exceptions** — even if the agent believes adding a
  "compiler flag" to this file will fix a compilation error, it will NOT.
  This file only contains download metadata and credentials.

---

## 23. [UNIVERSAL] Overriding HARD GATE After User Says "Continue" — Unauthorized Bypass

- **Symptom**: Agent ran `sanity_check.sh --dx_rt` which failed (NPU device initialization failure).
  Agent ran `install.sh`, sanity check still failed. User said "use recommended defaults and work
  to completion". Agent reinterpreted this as permission to override the HARD GATE and continued
  building for 70+ minutes. Result: hybrid CPU/NPU workaround instead of proper NPU deployment.
- **Root Cause**: No explicit rule that user instructions cannot override the sanity check HARD GATE
  STOP. Agent rationalized "user wants me to continue" as overriding "STOP if still failing".
  Also marked the prerequisite check as "done" despite it never passing.
- **Fix**: The HARD GATE STOP is **unconditional**. Even explicit user instructions to continue
  do NOT override it. If NPU hardware initialization fails after install.sh:
  1. Inform user that a cold boot / system reboot is required
  2. STOP and wait for user to reboot and re-run `sanity_check.sh --dx_rt`
  3. NEVER proceed with code generation while sanity_check.sh is failing
  4. NEVER mark the prerequisite check as "done" when it actually failed
- **Exception — compiler-only tasks**: When the task is purely ONNX → DXNN compilation
  (no dx_app/dx_stream demo app generation), compilation itself can proceed because
  `dxcom` runs on CPU without NPU hardware. However:
  - NPU-based verification (verify.py) must be marked as **SKIPPED**, not PASS
  - The user must be informed that verification requires NPU recovery (cold boot)
  - `session.log` must record `sanity_check=FAIL, verification=SKIPPED`
  - If the task also involves dx_app/dx_stream work, the full STOP rule applies
- **Prevention**: The HARD GATE rules now explicitly list "reinterpreting user's 'just continue' /
  'work to completion' / autopilot instructions as permission to override" as a PROHIBITED bypass.

---

## 24. [DX_COMPILER] Passing Both `config=` and `dataloader=` to dx_com.compile()

- **Symptom**: Compilation fails with an error about conflicting parameters when both `config=`
  and `dataloader=` are passed to `dx_com.compile()` at the same time.
- **Root Cause**: `dx_com.compile()` accepts either `config=` (path to config.json with
  `default_loader` section) OR `dataloader=` (a custom PyTorch DataLoader), but NOT both.
- **Fix**: When using a custom `DataLoader`, omit `config=` from `dx_com.compile()`. Pass
  calibration parameters directly as keyword arguments:
  ```python
  # WRONG — both config= and dataloader= together:
  dx_com.compile(..., config=cfg_path, dataloader=calib_loader, ...)

  # CORRECT — use dataloader= without config=:
  dx_com.compile(
      model="model.onnx",
      output_dir="./",
      dataloader=calib_loader,
      calibration_method="ema",
      calibration_num=100,
      opt_level=1,
      gen_log=True,
  )
  ```

## 25. [DX_COMPILER] Hand-Rolling PT→ONNX→dxcom for a YOLO Detection Model

- **Symptom**: For an Ultralytics YOLO **detection** model headed to DeepX, the agent
  manually exports ONNX, writes a config.json, and invokes `dxcom` — hitting the usual
  multi-output-graph (Pitfall: 6 outputs instead of 1) and NHWC/NCHW (#18) errors.
- **Root Cause**: Ultralytics now ships a first-class `format=deepx` exporter that does
  ONNX export → INT8 EMA calibration → `dx_com` compilation → packaging in ONE command.
  Hand-rolling the pipeline re-introduces errors the integrated exporter already handles.
- **Fix**: For YOLO **detection** + DeepX, use the one-shot path:
  ```bash
  yolo export model=yolo26n.pt format=deepx     # creates 'yolo26n_deepx_model/'
  ```
  ```python
  from ultralytics import YOLO
  YOLO("yolo26n.pt").export(format="deepx")      # int8=True enforced
  ```
  Notes: **x86-64 Linux only** (`dx_com` no ARM64); **detection only** (other tasks →
  manual fallback); **INT8 enforced** (`int8=False` overridden); output is a **directory**
  `<model>_deepx_model/{*.dxnn,config.json,metadata.yaml}`, not a bare `.dxnn`. Deploy with
  `YOLO("<model>_deepx_model")`. Full reference: `.deepx/toolsets/ultralytics-deepx-export.md`.
  Fall back to the manual PT→ONNX→`dxcom` pipeline only for non-detection / non-YOLO /
  custom-graph cases or when fine `config.json` control is required.
