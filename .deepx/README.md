# .deepx/ — dx-compiler Agent-Driven Knowledge

> Agent-Driven infrastructure for the DEEPX DXNN Compiler (DX-COM v2.5.0).
> Enables AI coding agents to automate ONNX → DXNN model compilation workflows
> targeting DEEPX NPU hardware (DX-M1).

## Directory Structure

```
.deepx/
├── README.md                          ← This file — master index
├── agents/
│   ├── dx-compiler-builder.md         ← Router agent (classifies & dispatches)
│   ├── dx-model-converter.md          ← PT → ONNX conversion agent
│   └── dx-dxnn-compiler.md            ← ONNX → DXNN compilation agent
├── skills/
│   ├── dx-agent-compiler-convert/
│   │   └── SKILL.md                   ← /dx-agent-compiler-convert skill
│   ├── dx-agent-compiler-compile/
│   │   └── SKILL.md                   ← /dx-agent-compiler-compile skill
│   ├── dx-agent-compiler-validate/
│   │   └── SKILL.md                   ← /dx-agent-compiler-validate skill
│   ├── dx-agent-compiler-pre-optimize/
│   │   └── SKILL.md                   ← /dx-agent-compiler-pre-optimize skill
│   ├── dx-agent-brainstorm/
│   │   └── SKILL.md                   ← Process skill
│   ├── dx-agent-tdd/
│   │   └── SKILL.md                   ← Process skill
│   └── dx-agent-verify/
│       └── SKILL.md                   ← Process skill
├── instructions/
│   ├── coding-standards.md            ← Python & config coding standards
│   └── compilation-workflow.md        ← End-to-end compilation reference
├── toolsets/
│   ├── dxcom-api.md                   ← Python API reference (dx_com.compile)
│   ├── dxcom-cli.md                   ← CLI reference (dxcom)
│   ├── config-schema.md               ← JSON config schema reference
│   ├── ultralytics-deepx-export.md    ← Ultralytics YOLO format=deepx export
│   ├── ultralytics-train-eval.md      ← Ultralytics retraining and evaluation
│   └── paddlepaddle-deepx.md          ← PaddleOCR / PaddlePaddle on DeepX
├── memory/
│   ├── MEMORY.md                      ← Memory index & update protocol
│   └── common_pitfalls.md             ← Domain-tagged pitfalls
└── scripts/
    ├── pre_optimize_find_heads.py     ← pre_optimize head finder + verifier
    └── validate_framework.py          ← Framework validation script
```

## Agents

| Agent | File | Role |
|---|---|---|
| dx-compiler-builder | `agents/dx-compiler-builder.md` | Router — classifies task and dispatches to sub-agents |
| dx-model-converter | `agents/dx-model-converter.md` | Converts PyTorch models to ONNX format |
| dx-dxnn-compiler | `agents/dx-dxnn-compiler.md` | Compiles ONNX models to .dxnn using DX-COM |

## Toolsets

| Toolset | File | Covers |
|---|---|---|
| DX-COM Python API | `toolsets/dxcom-api.md` | `dx_com.compile()` signature, parameters, code examples |
| DX-COM CLI | `toolsets/dxcom-cli.md` | `dxcom` command-line options and invocation patterns |
| Config Schema | `toolsets/config-schema.md` | JSON config structure, auto-inference rules |
| Ultralytics DeepX Export | `toolsets/ultralytics-deepx-export.md` | One-shot `format=deepx` export for Ultralytics YOLO detection models |
| Ultralytics Train & Eval | `toolsets/ultralytics-train-eval.md` | Retraining, mAP and FPS evaluation for Ultralytics models |
| PaddlePaddle on DeepX | `toolsets/paddlepaddle-deepx.md` | PaddleOCR / PaddlePaddle model conversion and apps |

## Memory

| File | Purpose | When to Read |
|---|---|---|
| `memory/MEMORY.md` | Memory index and update protocol | Start of every session |
| `memory/common_pitfalls.md` | Known failure modes and fixes | Before compilation, on errors |

## Skills

| Skill | File | Trigger |
|---|---|---|
| /dx-agent-compiler-convert | `skills/dx-agent-compiler-convert/SKILL.md` | "convert", "export", "PT to ONNX" |
| /dx-agent-compiler-compile | `skills/dx-agent-compiler-compile/SKILL.md` | "compile", "ONNX to DXNN", "quantize" |
| /dx-agent-compiler-validate | `skills/dx-agent-compiler-validate/SKILL.md` | "validate", "verify", "check output" |
| /dx-agent-compiler-pre-optimize | `skills/dx-agent-compiler-pre-optimize/SKILL.md` | "pre_optimize", "head tensor names", "ppu to pre_optimize" |
| /dx-agent-brainstorm | `skills/dx-agent-brainstorm/SKILL.md` | "brainstorm", "plan", "design" (process skill) |
| /dx-agent-tdd | `skills/dx-agent-tdd/SKILL.md` | "TDD", "validation", "incremental" (process skill) |
| /dx-agent-verify | `skills/dx-agent-verify/SKILL.md` | "completion", "verify", "evidence" (process skill) |

## Instructions

| File | Covers |
|---|---|
| `instructions/coding-standards.md` | Python style, config conventions, naming, error handling |
| `instructions/compilation-workflow.md` | Full PT → ONNX → DXNN pipeline, calibration, PPU config |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/pre_optimize_find_heads.py` | Finds YOLO/RTMDet head Conv names and prints a verified `pre_optimize` block |
| `scripts/validate_framework.py` | Validates .deepx/ structure, cross-references, domain tags |

## Context Routing Table

| If the task mentions... | Read these files |
|---|---|
| **PyTorch, PT, export, convert** | `agents/dx-model-converter.md`, `skills/dx-agent-compiler-convert/SKILL.md` |
| **ONNX, compile, DXNN, quantize** | `agents/dx-dxnn-compiler.md`, `skills/dx-agent-compiler-compile/SKILL.md`, `toolsets/dxcom-api.md` |
| **CLI, command line, dxcom** | `toolsets/dxcom-cli.md` |
| **config, JSON, schema** | `toolsets/config-schema.md` |
| **calibration, quantization, INT8** | `instructions/compilation-workflow.md`, `toolsets/config-schema.md` |
| **PPU, YOLO, detection** | `toolsets/config-schema.md`, `instructions/compilation-workflow.md` |
| **pre_optimize, head tensor names, ppu to pre_optimize** | `skills/dx-agent-compiler-pre-optimize/SKILL.md`, `toolsets/config-schema.md` |
| **validate, verify, check** | `skills/dx-agent-compiler-validate/SKILL.md` |
| **error, fail, bug** | `memory/common_pitfalls.md` |
| **Brainstorm, plan, design** | `skills/dx-agent-brainstorm/SKILL.md` |
| **TDD, validation, incremental** | `skills/dx-agent-tdd/SKILL.md` |
| **Completion, verify, evidence** | `skills/dx-agent-verify/SKILL.md` |
| **ALWAYS read (every task)** | `memory/common_pitfalls.md`, `instructions/coding-standards.md` |

## Developer Workflow

```
1. Read AGENTS.md or CLAUDE.md          ← Entry point
2. Router classifies task               ← dx-compiler-builder
3. Route to sub-agent                   ← dx-model-converter OR dx-dxnn-compiler
4. Sub-agent loads skill                ← /dx-agent-compiler-convert OR /dx-agent-compiler-compile
5. Skill references toolsets            ← dxcom-api, dxcom-cli, config-schema
6. Check memory for pitfalls            ← common_pitfalls.md
7. Execute with validation gates        ← /dx-agent-compiler-validate
8. Update memory if new patterns found  ← MEMORY.md protocol
```

## Key Facts

- **Compiler**: DX-COM v2.5.0 — compiles ONNX to .dxnn for DEEPX NPU
- **Inspector**: Compilation Summary Report — `dxcom --export_html` writes a self-contained `<model>_summary.html`
- **Batch size**: Must be 1. Dynamic shapes not supported.
- **ONNX opset**: 11-21 supported
- **OS**: Ubuntu 20.04 / 22.04 / 24.04 / 26.04; Fedora 42–45, RHEL 9–10, CentOS Stream 9–10 (x86_64, glibc ≥ 2.31)
- **Python**: 3.8 - 3.14
- **Hardware targets**: DX-M1 (`dx_m1`)
- **Quantization**: INT8 via EMA, MinMax, or IQR calibration (opt-in: Q-PRO, and QAT via `qmaster` — see `toolsets/qat.md`)
- **PPU types**: Type 0 (anchor-based: YOLOv3/v4/v5/v7), Type 1 (anchor-free: YOLOX, YOLOv8-v12); Type 2 is deprecated — use `pre_optimize`
- **Compilation flow**: ONNX + config.json + calibration data → .dxnn
- **Two interfaces**: CLI (`dxcom`) and Python API (`dx_com.compile()`)

## Supported Tools

This compiler knowledge base is consumed by five AI coding tools:

- **Claude Code** — via `CLAUDE.md` plus on-demand `.deepx/` reads
- **GitHub Copilot** — via `.github/copilot-instructions.md`, `.github/agents/`, and `.github/skills/`
- **Cursor** — via `.cursor/rules/*.mdc`
- **OpenCode** — via `AGENTS.md`, `opencode.json`, and `.opencode/agents/`
- **Codex CLI** — via `AGENTS.md`, `.codex/skills/dx-codex-identity/SKILL.md`, and direct reads of `.deepx/skills/*/SKILL.md`

Codex CLI does not use Copilot-style `@mention` wrappers or OpenCode slash-command
adapters here. It starts from `AGENTS.md`, then reads canonical `.deepx/agents/*.md`
and `.deepx/skills/*/SKILL.md` files directly when it needs task-specific grounding.

## CI Drift Gate

This repo is checked by the `subrepo-gate` CI job (`.github/workflows/dx-agent-dev-subrepo-gate-{ghes,cloud}.yml`). What it runs, how to reproduce it locally and how to fix a red gate: [`docs/ci-subrepo-gate.md`](docs/ci-subrepo-gate.md).
