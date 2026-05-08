# .deepx/ — dx-compiler Agentic Knowledge

> Agentic infrastructure for the DEEPX DXNN Compiler (DX-COM v2.2.1).
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
│   ├── dx-agentic-compiler-convert.md            ← /dx-agentic-compiler-convert skill
│   ├── dx-agentic-compiler-compile.md            ← /dx-agentic-compiler-compile skill
│   ├── dx-agentic-compiler-validate.md         ← /dx-agentic-compiler-validate skill
│   ├── dx-brainstorm-and-plan.md      ← Process skill
│   ├── dx-tdd.md                      ← Process skill
│   └── dx-verify-completion.md        ← Process skill
├── instructions/
│   ├── coding-standards.md            ← Python & config coding standards
│   └── compilation-workflow.md        ← End-to-end compilation reference
├── toolsets/
│   ├── dxcom-api.md                   ← Python API reference (dx_com.compile)
│   ├── dxcom-cli.md                   ← CLI reference (dxcom)
│   └── config-schema.md              ← JSON config schema reference
├── memory/
│   ├── MEMORY.md                      ← Memory index & update protocol
│   └── common_pitfalls.md             ← Domain-tagged pitfalls
└── scripts/
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

## Memory

| File | Purpose | When to Read |
|---|---|---|
| `memory/MEMORY.md` | Memory index and update protocol | Start of every session |
| `memory/common_pitfalls.md` | Known failure modes and fixes | Before compilation, on errors |

## Skills

| Skill | File | Trigger |
|---|---|---|
| /dx-agentic-compiler-convert | `skills/dx-agentic-compiler-convert.md` | "convert", "export", "PT to ONNX" |
| /dx-agentic-compiler-compile | `skills/dx-agentic-compiler-compile.md` | "compile", "ONNX to DXNN", "quantize" |
| /dx-agentic-compiler-validate | `skills/dx-agentic-compiler-validate.md` | "validate", "verify", "check output" |
| /dx-brainstorm-and-plan | `skills/dx-brainstorm-and-plan.md` | "brainstorm", "plan", "design" (process skill) |
| /dx-tdd | `skills/dx-tdd.md` | "TDD", "validation", "incremental" (process skill) |
| /dx-verify-completion | `skills/dx-verify-completion.md` | "completion", "verify", "evidence" (process skill) |

## Instructions

| File | Covers |
|---|---|
| `instructions/coding-standards.md` | Python style, config conventions, naming, error handling |
| `instructions/compilation-workflow.md` | Full PT → ONNX → DXNN pipeline, calibration, PPU config |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/validate_framework.py` | Validates .deepx/ structure, cross-references, domain tags |

## Context Routing Table

| If the task mentions... | Read these files |
|---|---|
| **PyTorch, PT, export, convert** | `agents/dx-model-converter.md`, `skills/dx-agentic-compiler-convert.md` |
| **ONNX, compile, DXNN, quantize** | `agents/dx-dxnn-compiler.md`, `skills/dx-agentic-compiler-compile.md`, `toolsets/dxcom-api.md` |
| **CLI, command line, dxcom** | `toolsets/dxcom-cli.md` |
| **config, JSON, schema** | `toolsets/config-schema.md` |
| **calibration, quantization, INT8** | `instructions/compilation-workflow.md`, `toolsets/config-schema.md` |
| **PPU, YOLO, detection** | `toolsets/config-schema.md`, `instructions/compilation-workflow.md` |
| **validate, verify, check** | `skills/dx-agentic-compiler-validate.md` |
| **error, fail, bug** | `memory/common_pitfalls.md` |
| **Brainstorm, plan, design** | `skills/dx-brainstorm-and-plan.md` |
| **TDD, validation, incremental** | `skills/dx-tdd.md` |
| **Completion, verify, evidence** | `skills/dx-verify-completion.md` |
| **ALWAYS read (every task)** | `memory/common_pitfalls.md`, `instructions/coding-standards.md` |

## Developer Workflow

```
1. Read AGENTS.md or CLAUDE.md          ← Entry point
2. Router classifies task               ← dx-compiler-builder
3. Route to sub-agent                   ← dx-model-converter OR dx-dxnn-compiler
4. Sub-agent loads skill                ← /dx-agentic-compiler-convert OR /dx-agentic-compiler-compile
5. Skill references toolsets            ← dxcom-api, dxcom-cli, config-schema
6. Check memory for pitfalls            ← common_pitfalls.md
7. Execute with validation gates        ← /dx-agentic-compiler-validate
8. Update memory if new patterns found  ← MEMORY.md protocol
```

## Key Facts

- **Compiler**: DX-COM v2.2.1 — compiles ONNX to .dxnn for DEEPX NPU
- **Inspector**: DX-TRON v2.0.1 — visual .dxnn inspection (AppImage / web)
- **Batch size**: Must be 1. Dynamic shapes not supported.
- **ONNX opset**: 11-21 supported
- **OS**: Debian Linux (Ubuntu 20.04 / 22.04 / 24.04), x86_64
- **Python**: 3.8 - 3.12
- **Hardware targets**: DX-M1 (`dx_m1`)
- **Quantization**: INT8 via EMA or MinMax calibration
- **PPU types**: Type 0 (anchor-based: YOLOv3/v4/v5/v7), Type 1 (anchor-free: YOLOX, YOLOv8-v12)
- **Compilation flow**: ONNX + config.json + calibration data → .dxnn
- **Two interfaces**: CLI (`dxcom`) and Python API (`dx_com.compile()`)
