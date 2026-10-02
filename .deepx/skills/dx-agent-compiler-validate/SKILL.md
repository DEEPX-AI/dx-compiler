---
name: dx-agent-compiler-validate
description: Compilation validation and verification
---

# /dx-agent-compiler-validate — Compilation Validation Skill

> Validates .dxnn compilation output: file integrity, HTML summary report,
> reference comparison, and accuracy metrics reporting.

## Trigger Words

"validate", "verify", "check output", "inspect dxnn", "compilation check"

## Prerequisites Checklist

- [ ] Compilation completed (output directory exists)
- [ ] Compilation ran with `--export_html` (or `export_html=True`)
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

## Phase 2: Inspect the Compilation Summary Report

**Gate**: `<model>_summary.html` exists and the compiler logged the save line.

DX-COM writes a self-contained HTML report when compiled with `--export_html`
(CLI) or `export_html=True` (Python API). It embeds the interactive graph
viewer, NPU-vs-CPU workload distribution, per-partition CPU-fallback reasons,
input/output shapes, and the compilation settings — no separate viewer install.

```bash
# Compile with the report enabled
dxcom -m "${WORK_DIR}/model.onnx" -c "${WORK_DIR}/config.json" \
      -o "${WORK_DIR}/" --export_html

# Verify the report was produced
REPORT=$(ls "${WORK_DIR}"/*_summary.html 2>/dev/null | head -1)
if [ -z "${REPORT}" ]; then
    echo "FAIL: no *_summary.html — was --export_html passed?"
else
    echo "PASS: summary report at ${REPORT} ($(stat --format=%s "${REPORT}") bytes)"
fi
```

Report generation is best-effort: DX-COM warns and still succeeds if the
report fails, so a missing report never means the `.dxnn` is bad. Check
`compiler.log` for the skip reason.

Review in the report (open in any browser):
- Input/output shapes match expectations
- NPU subgraph coverage (higher = better)
- No unexpected CPU fallback partitions, and the stated fallback reasons

For the machine-checkable version of the same partition data, use the
`compiler.log` grep in Phase 3.

**Validation gate**: `*_summary.html` exists with non-zero size. Shapes correct.

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
  Report:     model_summary.html (generated)
```

## Error Recovery

| Issue | Action |
|---|---|
| .dxnn missing | Re-run compilation; check for errors in terminal output |
| No `*_summary.html` | Confirm `--export_html` was passed; check compiler.log for the report warning |
| High CPU fallback ratio | Use `--aggressive_partitioning`; check unsupported ops |
| Quantization warnings | Try `minmax` instead of `ema`; increase `calibration_num` |
