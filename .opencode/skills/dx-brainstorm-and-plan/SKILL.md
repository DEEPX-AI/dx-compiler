---
name: dx-brainstorm-and-plan
description: "Brainstorm and plan before any code generation. HARD-GATE: no code without approved plan."
---

# /dx-brainstorm-and-plan — Brainstorm & Plan Before Compilation

> **RIGID skill. HARD-GATE: No code, no commands, no compilation without
> an approved plan.**

## Trigger Words

"plan", "brainstorm", "new model", "compile this", "convert and compile"

## Type: RIGID

HARD-GATE skill. You MUST NOT generate config files, run dxcom, run
torch.onnx.export, or execute any compilation step until the plan is
approved by the user.

## Phase 1: Context Check

Gather facts before asking questions. Run silently:

```bash
ls *.onnx *.pt *.pth 2>/dev/null                    # Input model format
dxcom --help >/dev/null 2>&1 && echo "DX-COM: ok"    # Tool available?
ls dx_com/calibration_dataset/ 2>/dev/null | head -5  # Calibration data?
```

**Gate**: Know the input format and tool availability.

## Phase 2: Key Decisions (Ask the User)

**Q1 — Conversion needed?**
If PyTorch (.pt/.pth): "Your model is PyTorch. I'll convert to ONNX with
opset 13, batch=1, static shapes. Confirm input shape (e.g., 1,3,640,640)?"

**Q2 — Calibration data?**
DX-COM always quantizes to INT8. There is NO precision selection parameter
(no FP16/FP32 option). NEVER ask the user to choose output precision.
"Do you have calibration images representative of inference data? How many?
(recommend 50-200). Calibration method: EMA (default) or MinMax?"

**Q3 — PPU? (detection models only)**
"Enable PPU post-processing? Type 0 = anchor-based (YOLOv3-v7),
Type 1 = anchor-free (YOLOv8+). Default: OFF."

**Q4 — ONNX simplification?**
"Run onnx-simplifier? May break node names, risk precision loss. Default: NO."

**Gate**: User answered Q1-Q2 minimum. Q3-Q4 asked if applicable.

## Phase 3: Build Execution Plan

```
## Compilation Plan
**Model**: <name>  **Format**: <ONNX|PyTorch>  **Target**: dx_m1

### Steps:
1. [ ] Create session directory: dx-agentic-dev/<session_id>/
2. [ ] <if PyTorch> Convert to ONNX → /dx-convert-model
3. [ ] Validate ONNX (opset, batch=1, static shapes, single output)
4. [ ] Generate config.json (match input name from ONNX graph)
5. [ ] Symlink calibration dataset
6. [ ] Compile ONNX → DXNN → /dx-compile-model
7. [ ] Validate output → /dx-validate-compile
8. [ ] Generate session report

**Routing**: /dx-convert-model → /dx-compile-model → /dx-validate-compile
```

**Gate**: User approves the plan ("looks good", "yes", "go ahead").

## Phase 4: Pre-Flight Check

ALL must pass before execution:

```bash
test -f "<model_path>" && echo "PASS: model exists" || echo "FAIL"
dxcom --help >/dev/null 2>&1 && echo "PASS: DX-COM ok" || echo "FAIL"
WORK_DIR="dx-agentic-dev/$(date +%Y%m%d-%H%M%S)_<model>_<task>"  # local timezone (NOT UTC)
mkdir -p "${WORK_DIR}" && echo "PASS: output dir ok" || echo "FAIL"
ls dx_com/calibration_dataset/*.jpg 2>/dev/null | wc -l
```

**Gate**: All pre-flight checks pass. If any FAIL, stop and resolve.

## Phase 5: Route to Skills

1. **PyTorch input** → `/dx-convert-model`
2. **ONNX ready** → `/dx-compile-model`
3. **Always** → `/dx-validate-compile`

## Anti-Patterns (NEVER Do)

- Starting compilation without asking Q1-Q2
- Running onnx-simplifier without explicit user approval
- Enabling PPU without user opt-in
- Skipping pre-flight checks
- Generating config.json before inspecting ONNX input names
