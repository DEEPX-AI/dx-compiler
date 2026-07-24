---
name: dx-agent-compiler-validate
description: Compilation validation and verification
---

# /dx-agent-compiler-validate — Compilation Validation Skill

> Validates .dxnn compilation output: file integrity, DX-TRON inspection,
> reference comparison, and accuracy metrics reporting.

## Trigger Words

"validate", "verify", "check output", "inspect dxnn", "compilation check"

## Prerequisites Checklist

- [ ] Compilation completed (output directory exists)
- [ ] DX-TRON available (AppImage or web mode)
- [ ] Original ONNX model accessible (for comparison)

## Phase 1: Check Output Artifacts

**Gate**: All expected files present.

```bash
# Verify .dxnn file exists
ls -la output/*.dxnn

# Verify compiler.log if gen_log was enabled
ls -la output/compiler.log

# Check .dxnn file size (should be > 0)
stat --format="%s bytes" output/*.dxnn
```

**Validation gate**: .dxnn file exists and has non-zero size.

## Phase 2: Inspect with DX-TRON

**Gate**: DX-TRON loads model without errors.

```bash
# Web server mode (recommended for remote/headless)
dx-tron --web --port 8080 output/model.dxnn
# Open http://localhost:8080 to inspect

# AppImage mode (local with display)
./DX-TRON-v2.0.1.AppImage output/model.dxnn
```

Verify in DX-TRON:
- Model graph renders correctly
- Input/output shapes match expectations
- NPU subgraph coverage (higher = better)
- No unexpected CPU fallback nodes

**Validation gate**: DX-TRON loads model. Graph renders. Shapes correct.

## Phase 3: Review Compiler Log

**Gate**: No errors or critical warnings in log.

```bash
# Check for errors
grep -i "error" output/compiler.log

# Check for warnings
grep -i "warning" output/compiler.log

# Check NPU vs CPU partition summary
grep -i "subgraph\|partition\|npu\|cpu" output/compiler.log

# Check quantization summary
grep -i "quantiz" output/compiler.log
```

**Validation gate**: Zero errors. Warnings reviewed and acceptable.

## Phase 3.5: Cross-Validation with Precompiled Reference Model

**Gate**: If a precompiled reference DXNN for the same model exists in
`dx-runtime/dx_app/assets/models/`, compare inference results to isolate
compilation issues from verification code issues.

> **Skip condition**: If no precompiled DXNN exists for the same model, skip
> this phase and proceed to Phase 4.

```bash
MODEL_NAME="<model_name>"
REF_DXNN="$SUITE_ROOT/dx-runtime/dx_app/assets/models/${MODEL_NAME}.dxnn"

if [ -f "$REF_DXNN" ]; then
    echo "=== Phase 3.5: Cross-Validation ==="

    # Run verify.py with precompiled (known-good) reference
    python verify.py --dxnn "$REF_DXNN"
    REF_RESULT=$?

    # Run verify.py with freshly compiled model
    python verify.py --dxnn output/${MODEL_NAME}.dxnn
    GEN_RESULT=$?

    # Diagnosis
    if [ $REF_RESULT -eq 0 ] && [ $GEN_RESULT -ne 0 ]; then
        echo "DIAGNOSIS: Compilation problem — reference passes, generated fails"
    elif [ $REF_RESULT -ne 0 ] && [ $GEN_RESULT -ne 0 ]; then
        echo "DIAGNOSIS: verify.py problem — both models fail"
    else
        echo "PASS: Cross-validation complete"
    fi
else
    echo "SKIP Phase 3.5: No precompiled reference for ${MODEL_NAME}"
fi
```

**Decision matrix**:
| Reference | Generated | Diagnosis |
|---|---|---|
| PASS | PASS | Compilation correct |
| PASS | FAIL | **Compilation problem** — check config, quantization, PPU |
| FAIL | FAIL | **Verification code problem** — fix verify.py first |
| FAIL | PASS | Reference may be outdated |

**Validation gate**: Cross-validation diagnosis recorded. If compilation problem found, fix and recompile before proceeding.

## Phase 4: Report

Generate validation report:

```
Validation Report:
  Model:      model.dxnn
  Size:       4.2 MB
  Status:     PASS
  NPU Ops:    142 / 150 (94.7%)
  CPU Ops:    8 / 150 (5.3%)
  Errors:     0
  Warnings:   2 (non-critical)
  DX-TRON:    Loaded successfully
```

## Error Recovery

| Issue | Action |
|---|---|
| .dxnn missing | Re-run compilation; check for errors in terminal output |
| DX-TRON fails to load | Check .dxnn integrity; recompile with `--gen_log` |
| High CPU fallback ratio | Use `--aggressive_partitioning`; check unsupported ops |
| Quantization warnings | Try `minmax` instead of `ema`; increase `calibration_num` |
