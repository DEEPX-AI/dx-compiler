---
name: dx-agent-tdd
description: Test-driven development for dx-compiler
---

<!-- AUTO-GENERATED from .deepx/ — DO NOT EDIT DIRECTLY -->
<!-- Source: .deepx/skills/dx-agent-tdd/SKILL.md -->
<!-- Run: dx-agent-gen generate -->

# /dx-agent-tdd — Test-Driven Development for dx-compiler

> **RIGID skill. Iron Law: No compilation step without a validation check
> first.** Every phase must have a check that runs BEFORE the next phase.

## Trigger Words

"test first", "validate before", "TDD", "check then compile"

## Type: RIGID

Iron Law skill. The Red-Green-Verify cycle is mandatory. You MUST NOT
proceed past any gate without a passing check.

## The Red-Green-Verify Cycle

```
RED    → Define what "correct" looks like (write the check)
GREEN  → Execute the step (conversion, compilation, etc.)
VERIFY → Run the check — must pass before proceeding
```

## Validation Order

### Check 1: Input Model File

```bash
# ONNX
test -f model.onnx && python -c "import onnx; onnx.checker.check_model(onnx.load('model.onnx')); print('PASS')" || echo "FAIL"
# PyTorch
test -f model.pt && python -c "import torch; torch.load('model.pt', map_location='cpu'); print('PASS')" || echo "FAIL"
```

**Gate**: File exists AND loads without error.

### Check 2: Compilation Config

```bash
python -c "
import json; cfg = json.load(open('config.json'))
assert 'inputs' in cfg, 'missing inputs'; assert 'target' in cfg, 'missing target'
print('PASS: config valid')
" || echo "FAIL"
```

Input name match:
```python
import onnx, json
model = onnx.load("model.onnx")
onnx_input = model.graph.input[0].name
config_input = list(json.load(open("config.json"))["inputs"].keys())[0]
assert onnx_input == config_input, f"MISMATCH: '{onnx_input}' vs '{config_input}'"
print(f"PASS: input name match — '{onnx_input}'")
```

**Gate**: Config parses AND input names match.

### Check 3: Conversion Output (PyTorch to ONNX)

```python
import onnx
model = onnx.load("model.onnx")
onnx.checker.check_model(model)
shape = [d.dim_value for d in model.graph.input[0].type.tensor_type.shape.dim]
assert shape[0] == 1, f"batch={shape[0]}, must be 1"
assert all(d > 0 for d in shape), f"dynamic shape {shape}"
assert len(model.graph.output) == 1, f"{len(model.graph.output)} outputs, expected 1"
print(f"PASS: shape={shape}, opset={model.opset_import[0].version}")
```

**Gate**: All assertions pass. Do not compile if FAIL.

### Check 4: Compiled .dxnn Output

```bash
DXNN_FILE=$(ls output/*.dxnn 2>/dev/null | head -1)
test -n "${DXNN_FILE}" && test -s "${DXNN_FILE}" \
  && echo "PASS: .dxnn exists ($(stat --format='%s' "${DXNN_FILE}") bytes)" \
  || echo "FAIL: .dxnn missing or empty"
```

**Gate**: File exists AND size > 0. If FAIL, review compiler.log.

### Check 5: DX-TRON Inspection

```bash
dx-tron --web --port 8080 output/model.dxnn &
TRON_PID=$!; sleep 3
curl -s http://localhost:8080/api/model/info | python -c "
import json, sys; info = json.load(sys.stdin)
print(f'Layers: {info.get(\"layer_count\",\"?\")}  Input: {info.get(\"input_shape\",\"?\")}')
print('PASS: DX-TRON metadata valid')
"
kill $TRON_PID 2>/dev/null
```

**Gate**: DX-TRON loads model without error. Shapes match expectations.

### Check 6: session.json

```bash
python -c "
import json; data = json.load(open('session.json'))
for k in ('model','target','timestamp'): assert k in data, f'missing {k}'
print('PASS: session.json valid')
" || echo "FAIL"
```

**Gate**: Parses and contains required keys.

## Framework Validation (Final Gate)

```bash
python .deepx/scripts/validate_framework.py
```

**Gate**: Exit code 0. If non-zero, fix before claiming completion.

## Cross-Validation with Reference Model (Post-TDD)

After all TDD gates pass, run Phase 5.7 cross-validation if a precompiled
reference DXNN exists in `dx-runtime/dx_app/assets/models/` for the same model.
This catches compilation-quality issues that structural TDD checks cannot detect
(e.g., quantization degradation, PPU misconfiguration).

```bash
MODEL_NAME="<model_name>"
REF_DXNN="$SUITE_ROOT/dx-runtime/dx_app/assets/models/${MODEL_NAME}.dxnn"
if [ -f "$REF_DXNN" ]; then
    echo "=== Cross-Validation ==="
    python verify.py --dxnn "$REF_DXNN"
    echo "Reference: $?"
    python verify.py --dxnn output/${MODEL_NAME}.dxnn
    echo "Generated: $?"
fi
```

See `dx-dxnn-compiler.md` Phase 5.7 for the full Differential Diagnosis Decision Matrix.

## Cycle Summary

| Step | Check | Gate |
|------|-------|------|
| 1 | Input model file | Exists, valid format |
| 2 | Compilation config | Parses, input name match |
| 3 | Conversion output | Valid ONNX, batch=1, static, single output |
| 4 | .dxnn output | Exists, non-zero size |
| 5 | DX-TRON inspection | Loads, metadata valid |
| 6 | session.json | Valid JSON, required keys |
| Final | Framework validator | Exit code 0 |

## Anti-Patterns (NEVER Do)

- Compiling before validating the ONNX model
- Proceeding past a FAIL gate
- Skipping config input name verification
- Assuming .dxnn is valid without DX-TRON check
- Running framework validator as the only check (it supplements, not replaces)
