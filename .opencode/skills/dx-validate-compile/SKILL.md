---
name: dx-validate-compile
description: "Validate .dxnn compilation output: file integrity, DX-TRON inspection, compiler log review, and report generation."
---

# /dx-validate-compile — Compilation Validation Skill

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
grep -i "error" output/compiler.log
grep -i "warning" output/compiler.log
grep -i "subgraph\|partition\|npu\|cpu" output/compiler.log
grep -i "quantiz" output/compiler.log
```

**Validation gate**: Zero errors. Warnings reviewed and acceptable.

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
