---
name: dx-verify-completion
description: "Verify before claiming done. Iron Law: no completion claims without fresh evidence."
---

# /dx-verify-completion — Verify Before Claiming Done

> **RIGID skill. Iron Law: No completion claims without fresh evidence.**
> Run every verification step and confirm passing output BEFORE telling
> the user compilation is complete, successful, or ready.

## Trigger Words

"done", "complete", "finished", "ready", "ship it", "verified"

## Type: RIGID

Evidence-before-assertions. Every claim of "it works" must be backed by
command output captured in the current session. Stale evidence does not count.

## Gate Function (5 Steps)

Execute ALL five steps in order. If any fails, STOP and fix before continuing.

### Step 1: Input Model Integrity

```bash
md5sum model.onnx
python -c "
import onnx; m = onnx.load('model.onnx')
print(f'Model: {m.graph.name or \"unnamed\"}  Opset: {m.opset_import[0].version}')
print(f'Inputs: {[i.name for i in m.graph.input]}')
print(f'Outputs: {[o.name for o in m.graph.output]}')
"
```

**Evidence**: File exists, hash captured, metadata printed.

### Step 2: Config Validity

```bash
python -c "
import json, onnx
cfg = json.load(open('config.json')); model = onnx.load('model.onnx')
print(f'Target: {cfg.get(\"target\", \"MISSING\")}')
onnx_name = model.graph.input[0].name
cfg_name = list(cfg['inputs'].keys())[0]
status = 'PASS' if onnx_name == cfg_name else 'FAIL'
print(f'Input name match: {status} (ONNX=\"{onnx_name}\", config=\"{cfg_name}\")')
"
```

**Evidence**: Config parses. Target set. Input names match.

### Step 3: Output .dxnn File

```bash
DXNN=$(ls output/*.dxnn 2>/dev/null | head -1)
if [ -z "${DXNN}" ]; then echo "FAIL: No .dxnn file"; exit 1; fi
SIZE=$(stat --format="%s" "${DXNN}")
echo "File: ${DXNN}  Size: ${SIZE} bytes ($(( SIZE / 1024 )) KB)"
[ "${SIZE}" -lt 1024 ] && echo "WARNING: suspiciously small" || echo "PASS: reasonable size"
```

**Evidence**: File path, size, PASS/WARNING status.

### Step 4: DX-TRON Inspection

```bash
dx-tron --web --port 8080 output/model.dxnn &
TRON_PID=$!; sleep 3
curl -s http://localhost:8080/api/model/info | python -c "
import json, sys; info = json.load(sys.stdin)
print('=== DX-TRON Model Info ===')
for k in ('layer_count','input_shape','output_shape','npu_subgraphs','cpu_subgraphs'):
    print(f'{k}: {info.get(k, \"N/A\")}')
print('PASS: DX-TRON inspection complete')
"
kill $TRON_PID 2>/dev/null
```

**Evidence**: DX-TRON loaded model. Shapes and partition visible.

### Step 5: Compiler Log Review

```bash
if [ -f output/compiler.log ]; then
    echo "=== Compiler Log Summary ==="
    grep -i "quantiz\|accuracy\|error\|warning\|npu\|cpu\|partition" output/compiler.log
    echo "PASS: compiler.log reviewed"
else
    echo "SKIP: No compiler.log (was --gen_log enabled?)"
fi
```

**Evidence**: Compiler log reviewed, or noted as unavailable.

### Final: Framework Validator

```bash
python .deepx/scripts/validate_framework.py
echo "Exit code: $?"
```

**Evidence**: Exit code 0 = PASS.

## Verification Checklist

Confirm ALL before claiming completion:

- [ ] Input model exists and is valid (Step 1)
- [ ] Config is valid JSON, input names match (Step 2)
- [ ] Output .dxnn exists with reasonable size (Step 3)
- [ ] DX-TRON loads model, metadata correct (Step 4)
- [ ] Compiler log reviewed, no errors (Step 5)
- [ ] Framework validator passes (Final)

## Completion Report Template

```
## Compilation Completion Report

**Session**: <session_id>
**Timestamp**: <ISO 8601>
**Status**: PASS | FAIL

### Input
- Model: <model_name.onnx>
- Format: ONNX (opset <N>)
- Input shape: <shape>
- MD5: <hash>

### Config
- Target: dx_m1
- Input name match: PASS
- PPU enabled: <yes/no>

### Output
- File: <output/model.dxnn>
- Size: <N> KB
- NPU ops: <N>/<total> (<percent>%)
- CPU ops: <N>/<total> (<percent>%)

### Validation
- DX-TRON: PASS
- Compiler log errors: 0
- Compiler log warnings: <N>
- Framework validator: PASS

### Output Structure
dx-agentic-dev/<session_id>/
├── model.onnx
├── config.json
├── model.dxnn
├── compiler.log
└── README.md
```

## Anti-Patterns (NEVER Do)

- Saying "compilation complete" without running Steps 1-5
- Relying on stale evidence from a previous session
- Skipping DX-TRON inspection because "the file exists"
- Claiming success when compiler.log contains errors
- Omitting the framework validator
- Reporting completion without the verification checklist
