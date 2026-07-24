# DEEPX Agent-Driven Development for DX-COM - dx-agent-dev (Beta)

> **Beta Feature** — Agent-Driven development support is under active development.
> Skill definitions and routing behavior may change between releases.

## Introduction

Compile ONNX models into DXNN format using natural language instructions. AI coding
agents understand the DX-COM compilation pipeline — config.json generation, calibration
data preparation, quantization strategies, and PPU configuration — so you can describe
*what* you want and let the agent handle the implementation details.

Supported workflows include:

- PyTorch model export to ONNX with automatic opset and shape configuration
- ONNX to DXNN compilation with INT8 quantization via DX-COM CLI or Python API
- End-to-end pipeline: PT → ONNX → DXNN with calibration and validation

## Prerequisites

| Requirement | Details |
|---|---|
| **DX-COM** | Installed via [DX-COM installation guide](02_02_Installation_of_DX-COM.md) (`pip install dx-com` or DEEPX package repository) |
| **AI coding agent** (one of) | Claude Code, GitHub Copilot (VS Code), Cursor, or OpenCode |
| **Python** | 3.8–3.12 |
| **ONNX** | opset 11–21 |
| **OS** | Debian Linux (Ubuntu 20.04/22.04/24.04), x86_64 |

## Architecture Overview

The agent-driven knowledge base for dx-compiler is organized in a single `.deepx/` directory
containing agents, skills, instructions, toolsets, and memory files that the agent reads
at task time.

### Compilation Pipeline

```
PyTorch (.pt)          ONNX (.onnx)                    DXNN (.dxnn)
    │                      │                                │
    ├──torch.onnx.export──►├──DX-COM compile───────────────►│
    │                      │   + config.json                │
    │                      │   + calibration data           │
    │                      │                                │
    │  dx-model-converter  │       dx-dxnn-compiler         │
    └──────────────────────┘────────────────────────────────┘
              dx-compiler-builder (router)
```

### Key Constraints

- Batch size must be 1
- Input shapes must be static (no dynamic axes)
- ONNX opset: 11–21
- Multi-input models: Python API only (not CLI)

> **Note:** Target device is always DX-M1 — agents should not ask about hardware selection.

## Available Agents and Skills

### Agents

| Agent | Description |
|---|---|
| `@dx-compiler-builder` | Master router — classifies tasks and routes to specialist agents |
| `@dx-model-converter` | Converts PyTorch models to ONNX format |
| `@dx-dxnn-compiler` | Compiles ONNX models to DXNN using DX-COM |

### Skills (All Platforms)

#### General SWE Process

| Skill | Description |
|-------|-------------|
| `/dx-swe-brainstorm` | Brainstorm and plan before any compilation task |
| `/dx-swe-tdd` | Test-driven development — validate each step incrementally |
| `/dx-swe-verify` | Verify before claiming completion — evidence before assertions |
| `/dx-swe-writing-plans` | Write implementation plans from specs or requirements |
| `/dx-swe-executing-plans` | Execute implementation plans with review checkpoints |
| `/dx-swe-debugging` | Systematic debugging before proposing fixes |
| `/dx-swe-parallel-agents` | Dispatch independent tasks to parallel agents |
| `/dx-swe-subagent-dev` | Execute plans with independent sub-agents |
| `/dx-swe-receiving-review` | Receive and process code review feedback |
| `/dx-swe-requesting-review` | Request code review before merging |
| `/dx-skill-router` | Route tasks to appropriate skills |

#### DEEPX Build

| Skill | Description |
|-------|-------------|
| `/dx-agent-compiler-compile` | Step-by-step ONNX to DXNN compilation workflow |
| `/dx-agent-compiler-convert` | Step-by-step PyTorch to ONNX conversion workflow |
| `/dx-agent-compiler-validate` | Validate compiled .dxnn model output |

## Supported AI Tools

Agent-Driven development works with five AI coding tools. Each tool auto-loads
the `.deepx/` knowledge base through its own configuration mechanism.

| Tool | Type | Auto-Load Mechanism | Agent Invocation |
|---|---|---|---|
| **Claude Code** | CLI | `CLAUDE.md` at project root | Free-form conversation; Context Routing Table dispatches automatically |
| **GitHub Copilot** | VS Code | `.github/copilot-instructions.md` | `@dx-compiler-builder "prompt"` in Copilot Chat |
| **Cursor** | IDE | `.cursor/rules/` (19 files: `dx-compiler.mdc`, 3 agent `.mdc` files, 15 `skill-*.mdc` files) | Free-form conversation; rules loaded by `alwaysApply` |
| **OpenCode** | CLI | `AGENTS.md` + `opencode.json` | `@dx-compiler-builder "prompt"` or `/dx-agent-compiler-compile` |
| **Codex CLI** | CLI | `AGENTS.md` + `.codex/skills/dx-codex-identity/SKILL.md` | Free-form conversation via `codex` / `codex exec`; inspect `.deepx/skills/*/SKILL.md` directly when needed |

### First-Time Setup

No additional configuration is needed. Open the `dx-compiler/` directory in your
preferred tool and the configuration files are loaded automatically:

```bash
# Claude Code
cd dx-all-suite/dx-compiler
claude

# OpenCode
cd dx-all-suite/dx-compiler
opencode

# Codex CLI
cd dx-all-suite/dx-compiler
codex

# GitHub Copilot — open folder in VS Code
code dx-all-suite/dx-compiler

# Cursor — open folder in Cursor
cursor dx-all-suite/dx-compiler
```

### Platform File Loading Reference

Each AI coding agent auto-loads different configuration files at the dx-compiler level.

#### Auto-Loaded Files

| File | Auto-loaded by | Loading |
|------|----------------|---------|
| `.github/copilot-instructions.md` | Copilot Chat/CLI | Auto |
| `CLAUDE.md` | Claude Code | Auto |
| `AGENTS.md` + `opencode.json` | OpenCode | Auto |
| `.cursor/rules/` (19 files) | Cursor | Auto |
| `AGENTS.md` + `.codex/skills/dx-codex-identity/SKILL.md` | Codex CLI | Auto |

#### Agent Files (Manual @mention)

| Agent | Copilot (`@mention`) | Claude Code (`@mention`) | OpenCode (`@mention`) |
|-------|------|---------|---------|
| `dx-compiler-builder` | `.github/agents/dx-compiler-builder.agent.md` | `.claude/agents/dx-compiler-builder.md` | `.opencode/agents/dx-compiler-builder.md` |
| `dx-dxnn-compiler` | `.github/agents/dx-dxnn-compiler.agent.md` | `.claude/agents/dx-dxnn-compiler.md` | `.opencode/agents/dx-dxnn-compiler.md` |
| `dx-model-converter` | `.github/agents/dx-model-converter.agent.md` | `.claude/agents/dx-model-converter.md` | `.opencode/agents/dx-model-converter.md` |

> **Codex CLI note:** Codex does not use `@mention` agent wrappers here. It reads
> `AGENTS.md` automatically and then consults `.deepx/agents/*.md` or
> `.deepx/skills/*/SKILL.md` directly for deeper grounding.

#### Skill Files (All Platforms)

Skills exist across all platforms:

- `.deepx/skills/` — canonical definitions (15 skills)
- `.github/skills/` — Copilot inline copies
- `.claude/skills/` — Claude thin wrappers
- `.opencode/agents/` — OpenCode, via skill references
- `.cursor/rules/skill-*.mdc` — Cursor rules
- `.codex/skills/dx-codex-identity/` — Codex auto-loaded identity wrapper; task-specific skills are read from `.deepx/skills/` directly

| Skill | File |
|-------|------|
| `/dx-swe-brainstorm` | `.deepx/skills/dx-swe-brainstorm/SKILL.md` |
| `/dx-agent-compiler-compile` | `.deepx/skills/dx-agent-compiler-compile/SKILL.md` |
| `/dx-agent-compiler-convert` | `.deepx/skills/dx-agent-compiler-convert/SKILL.md` |
| `/dx-swe-parallel-agents` | `.deepx/skills/dx-swe-parallel-agents/SKILL.md` |
| `/dx-swe-executing-plans` | `.deepx/skills/dx-swe-executing-plans/SKILL.md` |
| `/dx-swe-receiving-review` | `.deepx/skills/dx-swe-receiving-review/SKILL.md` |
| `/dx-swe-requesting-review` | `.deepx/skills/dx-swe-requesting-review/SKILL.md` |
| `/dx-skill-router` | `.deepx/skills/dx-skill-router/SKILL.md` |
| `/dx-swe-subagent-dev` | `.deepx/skills/dx-swe-subagent-dev/SKILL.md` |
| `/dx-swe-debugging` | `.deepx/skills/dx-swe-debugging/SKILL.md` |
| `/dx-swe-tdd` | `.deepx/skills/dx-swe-tdd/SKILL.md` |
| `/dx-agent-compiler-validate` | `.deepx/skills/dx-agent-compiler-validate/SKILL.md` |
| `/dx-swe-verify` | `.deepx/skills/dx-swe-verify/SKILL.md` |
| `/dx-swe-writing-plans` | `.deepx/skills/dx-swe-writing-plans/SKILL.md` |

#### Shared Knowledge Base (`.deepx/`)

The `.deepx/` directory is the **canonical source** for all platform-specific files. The `dx-agent-gen` generator transforms agents, skills, and templates into platform-specific files for Copilot (`.github/`), Claude Code (`.claude/`), OpenCode (`.opencode/`), and Cursor (`.cursor/rules/`). Runtime knowledge files (memory, instructions, toolsets) are read on demand by agents during task execution.

| Directory | Files | Description |
|-----------|-------|-------------|
| `.deepx/agents/` | `dx-compiler-builder.md`, `dx-dxnn-compiler.md`, `dx-model-converter.md` | Authoritative agent definitions — `dx-agent-gen` generates platform copies to `.github/agents/`, `.claude/agents/`, `.opencode/agents/`, and `.cursor/rules/` |
| `.deepx/templates/` | `{en,ko}/*.tmpl` | Instruction file templates (fragments via parent traversal to suite root) |
| `.deepx/toolsets/` | `dxcom-api.md`, `dxcom-cli.md`, `config-schema.md` | API and CLI reference |
| `.deepx/instructions/` | `coding-standards.md`, `compilation-workflow.md` | Coding conventions and workflow rules |
| `.deepx/memory/` | `common_pitfalls.md`, `MEMORY.md` | Persistent knowledge — pitfalls and session memory |

#### Generation Pipeline

All platform-specific files (`.github/`, `.claude/`, `.opencode/`, `.cursor/rules/`) are generated from `.deepx/` by `dx-agent-gen`:

```bash
dx-agent-gen generate --repo dx-compiler
```

A pre-commit hook enforces no drift between `.deepx/` sources and generated platform files. **Platform files should never be edited directly** — always edit the canonical `.deepx/` source and re-run the generator.

## User Scenarios

### Mandatory Brainstorming Questions

Before any compilation task, the agent asks three mandatory questions to ensure
correct configuration. These questions cannot be skipped.

#### Q1: NMS-Free Model Detection (PT → ONNX tasks)

For YOLO models, the agent auto-detects NMS-free capability and presents a YOLO
version characteristics table showing anchor type, NMS-free support, and PPU type
for each version (v3–v26). The recommended export mode depends on the model's
NMS-free architecture:

- **NMS-free models** (YOLOv10, YOLO26): **end2end=True** (recommended) — native
  NMS-free output `[1, 300, 6]`, no postprocessing needed. These models use
  one-to-one matching natively.
- **Optional NMS-free models** (YOLOv8, v9, v11, v12): **end2end=False** (recommended,
  default) — fused output `[1, 84, 8400]`, requires NMS postprocessing but gives
  full control over NMS parameters.

#### Q2: ONNX Simplification

Default is OFF. The agent presents pros (graph cleanup, reduced model size) and cons
(numerical precision loss, debugging difficulty, model breakage risk, input name changes).
The user confirms whether to run `onnx-simplifier` after export.

#### Q3: PPU Compilation Support (ONNX → DXNN tasks)

For detection models, the agent auto-detects PPU eligibility and presents the trade-off:

- **Without PPU** (default) — full control over NMS parameters at inference time
- **With PPU** — post-processing runs on hardware, simpler deployment

If PPU is enabled, the agent auto-infers PPU type from the model family (type 0 for
anchor-based YOLOv3–v7, type 1 for anchor-free YOLOv8+).

### Scenario 1: Convert PyTorch Model to ONNX

**Prompt:**

```
"Convert my yolo26x-custom.pt to ONNX with opset 17 and input shape [1, 3, 640, 640]"
```

| Tool | How to Use |
|---|---|
| **Claude Code** | Open `dx-compiler/` and type the prompt directly. |
| **GitHub Copilot** | `@dx-model-converter` followed by the prompt. |
| **Cursor** | Open `dx-compiler/` and type the prompt. |
| **OpenCode** | `/dx-agent-compiler-convert` or `@dx-model-converter` followed by the prompt. |

### Scenario 2: Compile ONNX to DXNN

**Prompt:**

```
"Compile model.onnx to DXNN with INT8 quantization using EMA calibration with 200 samples from ./calibration_images/"
```

| Tool | How to Use |
|---|---|
| **Claude Code** | Open `dx-compiler/` and type the prompt directly. |
| **GitHub Copilot** | `@dx-dxnn-compiler` followed by the prompt. |
| **Cursor** | Open `dx-compiler/` and type the prompt. |
| **OpenCode** | `/dx-agent-compiler-compile` or `@dx-dxnn-compiler` followed by the prompt. |

### Scenario 3: Full Pipeline PT → DXNN

**Prompt:**

```
"Convert my yolo26x-custom.pt to DXNN for DX-M1"
```

| Tool | How to Use |
|---|---|
| **Claude Code** | Open `dx-compiler/` and type the prompt. The router agent orchestrates both conversion and compilation. |
| **GitHub Copilot** | `@dx-compiler-builder` followed by the prompt. |
| **Cursor** | Open `dx-compiler/` and type the prompt. |
| **OpenCode** | `@dx-compiler-builder` followed by the prompt. |

## Config Auto-Inference

When you provide a model and calibration data, the agent automatically infers:

| Field | Auto-Inferred From |
|---|---|
| `inputs` shape | ONNX model metadata (`onnx.load()` → `graph.input`) |
| `calibration_method` | Default `ema` (recommended for most models) |
| `preprocessings.resize` | Input shape dimensions (H, W) |
| `preprocessings.normalize` | Model family (ImageNet defaults for classification, [0,1] for YOLO) |
| `ppu.type` | Model architecture (0 for anchor-based, 1 for anchor-free) |
| `ppu.num_classes` | ONNX output shape analysis |

## Output Isolation

All compilation artifacts go to `dx-agent-dev/<session_id>/` by default.
This keeps each compilation session self-contained and reproducible.

**Session ID format**: `YYYYMMDD-HHMMSS_<agent>_<model>_<task>` where `<agent>` is `claude`, `codex`, `copilot`, `cursor`, or `opencode`

| Output Type | Path | When |
|---|---|---|
| **Default (isolated)** | `dx-agent-dev/<session_id>/` | Always, unless user says otherwise |
| **Custom** | User-specified path via `-o` | When explicitly requested |

**Working directory contents** after compilation:
```
dx-agent-dev/<session_id>/
├── calibration_dataset   → ../../dx_com/calibration_dataset/ (symlink)
├── config.json           (auto-generated)
├── model.onnx            (input or converted)
├── model.dxnn        (compiled output)
├── compiler.log          (compilation log)
├── detect_model.py       (inference application)
├── verify.py             (ONNX vs DXNN verification)
├── setup.sh              (environment setup)
├── run.sh                (inference launcher)
└── README.md             (session report with file list)
```

## Calibration Dataset Management

The agent automatically manages calibration data:

1. Checks if `dx_com/calibration_dataset/` exists (100 JPEG images)
2. If missing, runs `example/2-download_sample_calibration_dataset.sh`
3. Creates a symlink in the session working directory
4. Uses relative path `./calibration_dataset` in config.json (never absolute)

## Sample Model Workflow

The `example/` directory provides a complete 3-step workflow for testing the
compilation pipeline with pre-built sample models:

```bash
cd dx-compiler
./example/1-download_sample_models.sh      # Download ONNX + JSON configs
./example/2-download_sample_calibration_dataset.sh  # Download calibration dataset
./example/3-compile_sample_models.sh       # Compile all sample models to .dxnn
```

**Available sample models**: YOLOV5S-1, YOLOV5S_Face-1, MobileNetV2-1

The downloaded JSON config files serve as canonical references for agents generating
config.json for new models — they demonstrate proper input naming, preprocessing
parameters, calibration settings, and PPU configuration.

## Session Sentinels

Agents output fixed markers at the start and end of each task for automated testing:

| Marker | When |
|---|---|
| `[DX-AGENT-DEV: START]` | First line of the agent's response |
| `[DX-AGENT-DEV: DONE (output-dir: <relative_path>)]` | Last line after all work is complete. `<relative_path>` is the session output directory relative to the project root. If no files were generated, omit the `(output-dir: ...)` part. |

Rules:

1. **CRITICAL** — Output `[DX-AGENT-DEV: START]` as the absolute first line of your first response, before any other text. This is non-negotiable even if the user says to proceed autonomously.
2. Output `[DX-AGENT-DEV: DONE (output-dir: <path>)]` as the very last line after all work is complete.
3. Sub-agents invoked via handoff do not output sentinels — only the top-level agent does.
4. If the user sends multiple prompts in a session, output START/DONE for each prompt.
5. The `output-dir` in DONE must be the relative path from the project root to the session output directory.
6. **Never output DONE after only producing planning artifacts** (specs, plans, design documents). DONE means all deliverables are produced — implementation code, scripts, configs, and validation results.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ValueError: Batch size must be 1` | Model has batch > 1 | Re-export ONNX with batch=1 input shape |
| `KeyError` in config.json inputs | Input name doesn't match ONNX model | Use `onnx.load(model).graph.input[0].name` to get correct name |
| Compilation hangs at calibration | Not enough calibration images or wrong file extensions | Verify `dataset_path` exists and contains images matching `file_extensions` |
| Low accuracy after compilation | Calibration data not representative | Use real-world inference images, increase `calibration_num` to 200+ |
| `ONNX opset not supported` | Opset < 11 or > 21 | Re-export with `opset_version=17` (recommended) |
| PPU output format mismatch | Wrong PPU type for model architecture | Use type=0 for YOLOv3/v4/v5/v7, type=1 for YOLOX/v8/v9/v10/v11/v12 |
| ONNX has 6 outputs instead of 1 | Ultralytics YOLO `Detect.export` flag not set | Use `model.export(format="onnx")` or set `Detect.export=True` before `torch.onnx.export()`. See Pitfall #10 in `.deepx/memory/common_pitfalls.md` |
| Inference gives wrong class labels | Postprocessing class index mismatch | Run `verify.py` to compare ONNX vs DXNN output. Check 0-indexed vs 1-indexed COCO classes |
| No detections from compiled model | Postprocessing bug in generated app | Run `verify.py`. Check output tensor shape parsing and confidence threshold |

## Mandatory Output Artifacts

Every compilation session that generates an inference application MUST also produce
these deployment artifacts in the session directory:

| Artifact | Purpose |
|---|---|
| `setup.sh` | Checks dx-runtime installation via `sanity_check.sh`, installs missing components via `install.sh`; checks dxcom availability, installs via `dx-compiler/install.sh` if missing; creates venv, installs dx_engine, opencv-python, numpy, onnxruntime |
| `run.sh` | One-command inference launcher with task-aware sample image paths |
| `README.md` | Session summary: pipeline, generated files, quick start, environment info |
| `verify.py` | ONNX vs DXNN inference comparison — catches postprocessing bugs |

The user should be able to run `bash setup.sh && bash run.sh` immediately after
compilation with zero manual setup.

## TDD Verification Gate

Before presenting the final compilation report, the agent runs `verify.py` to
compare ONNX inference (ground truth) against DXNN inference output:

- Uses sample images from `dx-runtime/dx_app/sample/` — selected based on model task:
  - Object Detection: `img/sample_dog.jpg`, `img/sample_horse.jpg`
  - Face Detection: `img/sample_face.jpg`, `img/sample_crowd.jpg`
  - Pose: `img/sample_people.jpg` | Hand: `img/sample_hand.jpg`
  - OBB: `dota8_test/P0177.png` | Segmentation: `img/sample_street.jpg`
  - Classification: `ILSVRC2012/0.jpeg` | Super Resolution: `img/sample_superresolution.png`
  - Low-light: `img/sample_lowlight.jpg` | Denoising: `img/sample_denoising.jpg`
- Compares detection count (within 20%), class labels (top-K match), bbox IoU (avg > 0.5)
- **PASS** → compilation and inference app are correct
- **FAIL** → postprocessing bugs exist; agent must debug and fix before reporting success

This gate was introduced after real-world testing revealed that compiled models can
benchmark correctly (e.g., 139 FPS) while the generated inference application produces
wrong results due to postprocessing bugs (wrong class mapping, incorrect bbox decoding).
