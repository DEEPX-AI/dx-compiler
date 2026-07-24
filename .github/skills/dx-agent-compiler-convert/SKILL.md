---
name: dx-agent-compiler-convert
description: PyTorch to ONNX model conversion
---

<!-- AUTO-GENERATED from .deepx/ — DO NOT EDIT DIRECTLY -->
<!-- Source: .deepx/skills/dx-agent-compiler-convert/SKILL.md -->
<!-- Run: dx-agent-gen generate -->

# /dx-agent-compiler-convert — PyTorch to ONNX Conversion Skill

> Step-by-step workflow for converting PyTorch models to ONNX format
> suitable for DEEPX DX-COM compilation.

## Trigger Words

"convert", "export", "PT to ONNX", "torch to onnx", "pytorch export",
"YOLO to deepx", "format=deepx", "export to deepx"

## Phase 0: Path Selection (Ultralytics YOLO detection → DeepX shortcut)

**Before** running the manual PT→ONNX pipeline below, check whether the one-shot
Ultralytics exporter applies:

> **If** the model is an Ultralytics YOLO **detection** model AND the target is
> DeepX NPU → **prefer the one-shot `format=deepx` path**, which runs ONNX export
> → INT8 EMA calibration → `dx_com` compilation → packaging in a single command:
> ```bash
> yolo export model=yolo26n.pt format=deepx     # creates 'yolo26n_deepx_model/'
> ```
> This avoids the most common manual-pipeline errors (multi-output ONNX graph,
> NHWC/NCHW mismatch, calibration setup). See
> `.github/toolsets/ultralytics-deepx-export.md` for the full reference, args,
> constraints (x86-64 Linux only, detection only, INT8 enforced), and deployment.

**Fall back to the manual PT→ONNX→`dxcom` pipeline below** only when the one-shot
path does not apply: non-detection tasks (seg/pose/cls/obb), non-YOLO or custom
graphs, or when fine control over `config.json` / quantization is required.

## Prerequisites Checklist

- [ ] PyTorch model file (.pt or .pth) accessible
- [ ] Model class definition available (or TorchScript format)
- [ ] Target input shape known (must have batch=1)
- [ ] `torch`, `onnx`, `onnxruntime` installed
- [ ] `onnx-simplifier` installed (optional — only if user requests simplification)

## Phase -1: Model Acquisition (if no local model file)

**Gate**: A local `.pt` or `.pth` model file exists for conversion.

If the user did NOT provide a local `.pt`/`.pth` file path, or the specified
file does not exist, the agent MUST acquire it before proceeding:

1. **Identify** the model's official download source:
   | Model Family | Source | Download Method |
   |---|---|---|
   | Ultralytics YOLO (v5-v12, v26) | GitHub Releases / `ultralytics` pip | `from ultralytics import YOLO; YOLO("yolo11n.pt")` |
   | TorchVision (ResNet, MobileNet, etc.) | PyTorch Hub / torchvision | `torchvision.models.resnet50(weights="DEFAULT")` |
   | Timm models | `timm` pip | `timm.create_model("efficientnet_b0", pretrained=True)` |

2. **Download** the model:
   ```python
   # Example: Ultralytics YOLO
   from ultralytics import YOLO
   model = YOLO("yolo11n.pt")  # Auto-downloads to current directory

   # Example: TorchVision
   import torchvision, torch
   model = torchvision.models.resnet50(weights="DEFAULT")
   torch.save(model, "resnet50.pt")
   ```

3. **Verify** the download:
   ```bash
   test -f model.pt && echo "PASS: model downloaded" || echo "FAIL"
   ```

**NEVER** skip this phase by only providing download instructions or telling the
user to download the model themselves. The user expects the full pipeline:
download → convert → compile → `.dxnn` output.

**Validation gate**: Local `.pt`/`.pth` file exists and is non-empty.

## Phase 0: Prepare Working Directory

**Gate**: Session directory exists for output isolation.

1. Create session working directory (if not already provided by dx-compiler-builder):
   ```bash
   SESSION_ID="$(date +%Y%m%d-%H%M%S)_$(basename model.pt .pt)_pt_to_onnx"  # local timezone (NOT UTC)
   WORK_DIR="dx-agent-dev/${SESSION_ID}"
   mkdir -p "${WORK_DIR}"
   ```

2. Copy PyTorch model to working directory:
   ```bash
   cp model.pt "${WORK_DIR}/"
   ```

All subsequent phases save outputs to `${WORK_DIR}/`.

**Validation gate**: `${WORK_DIR}/` exists. Model file copied.

## Phase 1: Validate PyTorch Model

**Gate**: Model loads and runs inference successfully.

1. Load the model:
   ```python
   import torch
   model = torch.load("model.pt", map_location="cpu")
   # OR for state_dict:
   model = ModelClass()
   model.load_state_dict(torch.load("model.pt", map_location="cpu"))
   ```

2. Set to eval mode:
   ```python
   model.eval()
   ```

3. Test forward pass:
   ```python
   dummy = torch.randn(1, 3, 640, 640)
   with torch.no_grad():
       output = model(dummy)
   print(f"Output shape: {output.shape}")
   ```

**Validation gate**: Forward pass completes without error. Output shape is reasonable.

## Phase 2: Export to ONNX

**Gate**: ONNX file created and passes onnx.checker.

1. Define export parameters:
   ```python
   input_shape = (1, 3, 640, 640)  # Batch MUST be 1
   opset_version = 13              # Range: 11-21
   input_names = ["images"]        # Descriptive name
   output_names = ["output0"]      # Descriptive name
   ```

2. Export:
   ```python
   dummy_input = torch.randn(*input_shape)
   torch.onnx.export(
       model, dummy_input, f"{WORK_DIR}/model.onnx",
       opset_version=opset_version,
       input_names=input_names,
       output_names=output_names,
       dynamic_axes=None,  # Static shapes only for DEEPX
   )
   ```

3. Validate:
   ```python
   import onnx
   onnx_model = onnx.load(f"{WORK_DIR}/model.onnx")
   onnx.checker.check_model(onnx_model)
   ```

**Validation gate**: `onnx.checker.check_model()` passes. No dynamic dimensions.

## Phase 2a: Ultralytics YOLO Special Handling

> **IMPORTANT**: Ultralytics YOLO models (v8/v9/v10/v11/v12/v26) require special
> export handling. Standard `torch.onnx.export()` produces 6 ONNX outputs instead
> of 1 because the `Detect` head's `export` flag defaults to `False`.

**Detection**: If the model file name contains "yolo" and uses the `ultralytics`
package, or if `model.model[-1]` has an `export` attribute, apply this phase.

**Option A (Recommended) — Official Export API**:
```python
from ultralytics import YOLO
model = YOLO("model.pt")
model.export(format="onnx", opset=13, imgsz=640, simplify=False)
```
This automatically sets `export=True` on all detection heads.

**Option B — Manual Export with Flags**:
```python
from ultralytics import YOLO
model = YOLO("model.pt").model
model.eval()

for m in model.modules():
    if hasattr(m, "export"):
        m.export = True
    if hasattr(m, "_end2end"):
        m._end2end = False  # False → [1, 84, 8400], True → [1, 300, 6]

dummy = torch.randn(1, 3, 640, 640)
torch.onnx.export(model, dummy, f"{WORK_DIR}/model.onnx",
                   opset_version=13, input_names=["images"],
                   output_names=["output0"])
```

**Post-export verification** (MANDATORY):
```python
import onnx
onnx_model = onnx.load(f"{WORK_DIR}/model.onnx")
num_outputs = len(onnx_model.graph.output)
assert num_outputs == 1, (
    f"Expected 1 output, got {num_outputs}. "
    "Ultralytics YOLO: set Detect.export=True or use model.export(). "
    "See common_pitfalls.md #10."
)
```

**`end2end` output shape reference**:
| `end2end` | Shape | Postprocessing |
|---|---|---|
| `True` | `[1, 300, 6]` | None — NMS built-in |
| `False` | `[1, 84, 8400]` | Standard YOLO decode + NMS |

**Validation gate**: ONNX has exactly 1 output node. Shape matches expected format.

## Phase 3: Simplify ONNX (OPTIONAL — Only If User Explicitly Requests)

> **WARNING**: Do NOT run onnx-simplifier automatically. Only perform this phase
> if the user explicitly asks for simplification. Skip to Phase 4 by default.

**Risks of automatic simplification**:
1. Numerical precision loss from constant folding (FP32 rounding errors)
2. Original PyTorch layer/node names are altered, breaking debuggability
3. Models with complex control flow or custom ops may fail or produce incorrect graphs
4. Input node names may change, causing config.json `inputs` key mismatch

**Gate**: Simplified model produces same outputs as original.

If the user explicitly requests simplification:

1. Simplify:
   ```python
   import onnxsim
   simplified, check = onnxsim.simplify(onnx_model)
   assert check, "Simplification validation failed"
   onnx.save(simplified, f"{WORK_DIR}/model_simplified.onnx")
   ```

2. Verify shapes preserved:
   ```python
   for inp in simplified.graph.input:
       dims = [d.dim_value for d in inp.type.tensor_type.shape.dim]
       assert dims[0] == 1, "Batch must be 1"
       print(f"{inp.name}: {dims}")
   ```

3. **Re-verify input names** — simplifier may rename input nodes:
   ```python
   original_name = onnx_model.graph.input[0].name
   simplified_name = simplified.graph.input[0].name
   if original_name != simplified_name:
       print(f"WARNING: Input name changed: {original_name} → {simplified_name}")
       print("Update config.json inputs key accordingly!")
   ```

**Validation gate**: Simplified model passes checker. Shapes unchanged. Batch = 1.

## Phase 4: Final Report

Print summary for handoff to dx-dxnn-compiler:

```
Conversion Complete:
  Session:  dx-agent-dev/<session_id>/
  Output:   model.onnx
  Input:    images [1, 3, 640, 640]
  Output:   output0 [1, 25200, 85]
  Opset:    13
  Size:     15.1 MB
  Status:   Ready for DX-COM compilation

Generated Files:
  model.onnx              (raw export, 15.1 MB)
  model_simplified.onnx   (only if user requested simplification)
```

## Error Recovery

| Error | Recovery |
|---|---|
| `RuntimeError` during export | Try lower opset; check for unsupported ops |
| Dynamic shapes detected | Remove `dynamic_axes`; verify no data-dependent shapes |
| Checker fails | Re-export with different opset; inspect graph |
| Simplification fails | Skip simplification; proceed with unsimplified model (this is the default) |
| Multiple ONNX outputs (6) | Ultralytics YOLO: set `Detect.export=True` or use `model.export(format="onnx")` — see Phase 2a and Pitfall #10 |
| Model class not found | Ask user for model definition source code |
