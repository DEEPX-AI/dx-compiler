---
name: dx-convert-model
description: "Step-by-step PyTorch to ONNX conversion workflow. Handles model acquisition, validation, export with static shapes, and Ultralytics YOLO special handling."
---

# /dx-convert-model — PyTorch to ONNX Conversion Skill

> Step-by-step workflow for converting PyTorch models to ONNX format
> suitable for DEEPX DX-COM compilation.

## Trigger Words

"convert", "export", "PT to ONNX", "torch to onnx", "pytorch export"

## Prerequisites Checklist

- [ ] PyTorch model file (.pt or .pth) accessible
- [ ] Model class definition available (or TorchScript format)
- [ ] Target input shape known (must have batch=1)
- [ ] `torch`, `onnx`, `onnxruntime` installed
- [ ] `onnx-simplifier` installed (optional — only if user requests simplification)

## Phase -1: Model Acquisition (if no local model file)

**Gate**: A local `.pt` or `.pth` model file exists for conversion.

If the user did NOT provide a local file, the agent MUST acquire it:

| Model Family | Source | Download Method |
|---|---|---|
| Ultralytics YOLO (v5-v12, v26) | GitHub Releases / `ultralytics` pip | `from ultralytics import YOLO; YOLO("yolo11n.pt")` |
| TorchVision (ResNet, MobileNet, etc.) | PyTorch Hub / torchvision | `torchvision.models.resnet50(weights="DEFAULT")` |
| Timm models | `timm` pip | `timm.create_model("efficientnet_b0", pretrained=True)` |

**NEVER** skip this phase by only providing download instructions.

**Validation gate**: Local `.pt`/`.pth` file exists and is non-empty.

## Phase 0: Prepare Working Directory

**Gate**: Session directory exists for output isolation.

```bash
SESSION_ID="$(date +%Y%m%d-%H%M%S)_$(basename model.pt .pt)_pt_to_onnx"  # local timezone (NOT UTC)
WORK_DIR="dx-agentic-dev/${SESSION_ID}"
mkdir -p "${WORK_DIR}"
cp model.pt "${WORK_DIR}/"
```

**Validation gate**: `${WORK_DIR}/` exists. Model file copied.

## Phase 1: Validate PyTorch Model

**Gate**: Model loads and runs inference successfully.

1. Load the model (`torch.load` or state_dict)
2. Set to eval mode: `model.eval()`
3. Test forward pass with dummy input (batch=1)

**Validation gate**: Forward pass completes. Output shape is reasonable.

## Phase 2: Export to ONNX

**Gate**: ONNX file created and passes onnx.checker.

```python
torch.onnx.export(
    model, dummy_input, f"{WORK_DIR}/model.onnx",
    opset_version=13,
    input_names=["images"],
    output_names=["output0"],
    dynamic_axes=None,  # Static shapes only for DEEPX
)
```

**Validation gate**: `onnx.checker.check_model()` passes. No dynamic dimensions.

## Phase 2a: Ultralytics YOLO Special Handling

> **IMPORTANT**: Ultralytics YOLO models (v8-v12, v26) require special export.
> Standard `torch.onnx.export()` produces 6 outputs instead of 1.

**Option A (Recommended)** — Official Export API:
```python
from ultralytics import YOLO
model = YOLO("model.pt")
model.export(format="onnx", opset=13, imgsz=640, simplify=False)
```

**Option B** — Manual Export with `Detect.export=True`

**Post-export verification (MANDATORY)**:
```python
assert len(onnx_model.graph.output) == 1, "Expected 1 output"
```

**`end2end` output shape reference**:
| `end2end` | Shape | Postprocessing |
|---|---|---|
| `True` | `[1, 300, 6]` | None — NMS built-in |
| `False` | `[1, 84, 8400]` | Standard YOLO decode + NMS |

**Validation gate**: ONNX has exactly 1 output node. Shape matches expected format.

## Phase 3: Simplify ONNX (OPTIONAL — Only If User Explicitly Requests)

> **WARNING**: Do NOT run onnx-simplifier automatically. Only if user explicitly asks.

Risks: precision loss, node name changes, config.json input key mismatch.

If user requests:
1. Simplify with `onnxsim.simplify()`
2. Verify shapes preserved, batch=1
3. Re-verify input names (simplifier may rename)

**Validation gate**: Simplified model passes checker. Shapes unchanged.

## Phase 4: Final Report

Print summary for handoff to `/dx-compile-model`:
- Session directory, output file, input/output shapes, opset, size, status

## Error Recovery

| Error | Recovery |
|---|---|
| `RuntimeError` during export | Try lower opset; check for unsupported ops |
| Dynamic shapes detected | Remove `dynamic_axes`; verify no data-dependent shapes |
| Checker fails | Re-export with different opset; inspect graph |
| Simplification fails | Skip simplification; proceed with unsimplified model |
| Multiple ONNX outputs (6) | Ultralytics YOLO: set `Detect.export=True` or use `model.export()` |
| Model class not found | Ask user for model definition source code |
