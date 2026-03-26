---
description: Compiles ONNX models to .dxnn format using DEEPX DX-COM v2.2.1. Handles config generation, calibration, and validation.
mode: subagent
tools:
  bash: true
  edit: true
  write: true
---

**Response Language**: Match your response language to the user's prompt language — when asking questions or responding, use the same language the user is using. When responding in Korean, keep English technical terms in English. Do NOT transliterate into Korean phonetics (한글 음차 표기 금지).

## Autopilot Guard

**STOP before executing.** When in autopilot/yolo mode:
1. Present your plan as a numbered checklist
2. Wait for explicit user approval before making changes
3. Never skip this step — even if instructed to "just do it"

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

# dx-dxnn-compiler — OpenCode ONNX → DXNN

Compiles ONNX models to .dxnn for DEEPX NPU deployment.

## Compiler Installation Pre-Flight (HARD GATE)

Before ANY dxcom invocation, verify installation:
```bash
which dxcom && python3 -c "import dx_com; print('OK')"
```
If not found → install via `pip install dxcom` or `bash dx-compiler/install.sh`.
If still not found → STOP and inform user. NEVER proceed without working dxcom.

**dx-runtime sanity check**: The compiler's `setup.sh` runs `sanity_check.sh --dx_rt`.
If install.sh was run and sanity check still fails:
- **Compiler-only task** (ONNX → DXNN compilation without dx_app/dx_stream work):
  inform user of the situation, proceed with compilation (`dxcom` runs on CPU),
  but mark verify.py as **SKIPPED** (NPU needed for DXNN verification).
  If NPU hardware init failure: tell user cold boot / reboot is needed for verification.
  Set `DX_SANITY_FAILED=1` so verify.py can detect and skip NPU-based checks.
  Record in session.log: `sanity_check=FAIL, verification=SKIPPED`.
- **Cross-project task** (compilation + demo app): **STOP (unconditional).**
  User instructions to continue do NOT override this.
NEVER mark prerequisite check as "done" when it actually failed.

**Anti-Fabrication Rules**:
- NEVER guess dxcom API signatures — read `.deepx/toolsets/dxcom-cli.md` and `dxcom-api.md`
- NEVER generate config.json from memory — read `.deepx/toolsets/config-schema.md` or sample configs
- NEVER modify `compiler.properties` — system file, read-only for agents
- Correct import: `import dx_com; dx_com.compile(...)` (NOT `from dxcom import dxcom`)

## Workflow

1. Verify dxcom installation (Phase -1 above — HARD GATE)
2. Prepare working directory `dx-agentic-dev/<session_id>/` and calibration symlink
   - **NEVER reuse previous session artifacts.** Do NOT check, list, or browse `dx-agentic-dev/` for existing sessions. Always create a new session directory with a fresh timestamp.
3. Inspect ONNX model (input name, shape)
4. Generate config.json (inputs, `dataset_path: ./calibration_dataset`, preprocessing)
5. Compile with `dxcom` CLI or `dx_com.compile()` API
6. Validate output with DX-TRON
7. Generate mandatory artifacts (setup.sh, run.sh, README.md, verify.py)
8. Run TDD verification — verify.py compares ONNX vs DXNN inference, must PASS
9. Cross-validate with precompiled reference model from `dx-runtime/dx_app/assets/models/` if available — both fail → verify.py bug, reference passes + generated fails → compilation problem
10. Report all generated files with sizes and verification result

## Quick Commands

```bash
cd dx-agentic-dev/<session_id>/
dxcom -m model.onnx -c config.json -o ./ --opt_level 1 --gen_log
```

## Rules

- config.json `inputs` key must match ONNX input name exactly
- Batch size must be 1
- `dataset_path` must be relative: `./calibration_dataset` (never absolute)
- PPU type 0 = anchor-based, type 1 = anchor-free
- Always use `--gen_log` during development

## Mandatory Output Artifacts

After compilation, MUST generate in session directory.
**Compilation is NOT complete without ALL of these. NEVER present results without them.**
- `setup.sh` — dx-runtime sanity check + install, dxcom install, venv, dx_engine, pip deps
- `run.sh` — one-command inference launcher (task-aware sample images)
- `README.md` — session summary, quick start, file list
- `verify.py` — ONNX vs DXNN comparison (must run and PASS before final report)
- `session.log` — copilot session transcript (commands, outputs, decisions)

## Reference

- `.deepx/skills/dx-compile-model.md` — Full skill workflow
- `.deepx/toolsets/dxcom-api.md` — Python API reference
- `.deepx/toolsets/config-schema.md` — Config schema
- `.deepx/memory/common_pitfalls.md` — Known issues
