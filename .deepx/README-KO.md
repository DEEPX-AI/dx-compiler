# .deepx/ — dx-compiler Agentic Knowledge

> DEEPX DXNN Compiler (DX-COM)를 위한 Agentic 인프라.
> AI 코딩 에이전트가 DEEPX NPU 하드웨어(DX-M1)를 대상으로
> ONNX → DXNN 모델 컴파일 워크플로를 자동화할 수 있도록 합니다.

## Directory Structure

```
.deepx/
├── README.md                          ← 이 파일 — 마스터 인덱스
├── agents/
│   ├── dx-compiler-builder.md         ← 라우터 에이전트 (분류 및 디스패치)
│   ├── dx-model-converter.md          ← PT → ONNX 변환 에이전트
│   └── dx-dxnn-compiler.md            ← ONNX → DXNN 컴파일 에이전트
├── skills/
│   ├── dx-agentic-compiler-convert.md            ← /dx-agentic-compiler-convert skill
│   ├── dx-agentic-compiler-compile.md            ← /dx-agentic-compiler-compile skill
│   ├── dx-agentic-compiler-validate.md         ← /dx-agentic-compiler-validate skill
│   ├── dx-brainstorm-and-plan.md      ← Process skill
│   ├── dx-tdd.md                      ← Process skill
│   └── dx-verify-completion.md        ← Process skill
├── instructions/
│   ├── coding-standards.md            ← Python 및 config 코딩 표준
│   └── compilation-workflow.md        ← 엔드 투 엔드 컴파일 레퍼런스
├── toolsets/
│   ├── dxcom-api.md                   ← Python API 레퍼런스 (dx_com.compile)
│   ├── dxcom-cli.md                   ← CLI 레퍼런스 (dxcom)
│   └── config-schema.md              ← JSON config 스키마 레퍼런스
├── memory/
│   ├── MEMORY.md                      ← 메모리 인덱스 및 업데이트 프로토콜
│   └── common_pitfalls.md             ← 도메인 태깅된 pitfalls
└── scripts/
    └── validate_framework.py          ← 프레임워크 검증 스크립트
```

## Agents

| Agent | File | 역할 |
|---|---|---|
| dx-compiler-builder | `agents/dx-compiler-builder.md` | 라우터 — 작업을 분류하고 서브 에이전트로 디스패치 |
| dx-model-converter | `agents/dx-model-converter.md` | PyTorch 모델을 ONNX 포맷으로 변환 |
| dx-dxnn-compiler | `agents/dx-dxnn-compiler.md` | DX-COM을 사용해 ONNX 모델을 .dxnn으로 컴파일 |

## Toolsets

| Toolset | File | 다루는 범위 |
|---|---|---|
| DX-COM Python API | `toolsets/dxcom-api.md` | `dx_com.compile()` 시그니처, 파라미터, 코드 예제 |
| DX-COM CLI | `toolsets/dxcom-cli.md` | `dxcom` 커맨드라인 옵션 및 호출 패턴 |
| Config Schema | `toolsets/config-schema.md` | JSON config 구조, 자동 추론 규칙 |

## Memory

| File | 목적 | 읽어야 할 시점 |
|---|---|---|
| `memory/MEMORY.md` | 메모리 인덱스 및 업데이트 프로토콜 | 모든 세션 시작 시 |
| `memory/common_pitfalls.md` | 알려진 실패 모드 및 수정 방법 | 컴파일 전, 에러 발생 시 |

## Skills

| Skill | File | 트리거 |
|---|---|---|
| /dx-agentic-compiler-convert | `skills/dx-agentic-compiler-convert.md` | "convert", "export", "PT to ONNX" |
| /dx-agentic-compiler-compile | `skills/dx-agentic-compiler-compile.md` | "compile", "ONNX to DXNN", "quantize" |
| /dx-agentic-compiler-validate | `skills/dx-agentic-compiler-validate.md` | "validate", "verify", "check output" |
| /dx-brainstorm-and-plan | `skills/dx-brainstorm-and-plan.md` | "brainstorm", "plan", "design" (process skill) |
| /dx-tdd | `skills/dx-tdd.md` | "TDD", "validation", "incremental" (process skill) |
| /dx-verify-completion | `skills/dx-verify-completion.md` | "completion", "verify", "evidence" (process skill) |

## Instructions

| File | 다루는 범위 |
|---|---|
| `instructions/coding-standards.md` | Python 스타일, config 컨벤션, 네이밍, 에러 처리 |
| `instructions/compilation-workflow.md` | 전체 PT → ONNX → DXNN 파이프라인, calibration, PPU config |

## Scripts

| Script | 목적 |
|---|---|
| `scripts/validate_framework.py` | .deepx/ 구조, 상호 참조, 도메인 태그 검증 |

## Context Routing Table

| 작업에 다음이 언급되면... | 다음 파일을 읽으세요 |
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
| **항상 읽기 (모든 작업)** | `memory/common_pitfalls.md`, `instructions/coding-standards.md` |

## Developer Workflow

```
1. AGENTS.md 또는 CLAUDE.md 읽기            ← 진입점
2. 라우터가 작업 분류                        ← dx-compiler-builder
3. 서브 에이전트로 라우팅                    ← dx-model-converter 또는 dx-dxnn-compiler
4. 서브 에이전트가 skill 로드                ← /dx-agentic-compiler-convert 또는 /dx-agentic-compiler-compile
5. Skill이 toolsets 참조                     ← dxcom-api, dxcom-cli, config-schema
6. Pitfalls를 위한 memory 확인               ← common_pitfalls.md
7. 검증 게이트와 함께 실행                   ← /dx-agentic-compiler-validate
8. 새 패턴 발견 시 memory 업데이트           ← MEMORY.md 프로토콜
```

## Key Facts

- **Compiler**: DX-COM — ONNX를 DEEPX NPU용 .dxnn으로 컴파일
- **Inspector**: DX-TRON v2.0.1 — 시각적 .dxnn 검사 (AppImage / 웹)
- **Batch size**: 1이어야 함. Dynamic shapes는 지원하지 않음.
- **ONNX opset**: 11-21 지원
- **OS**: Debian Linux (Ubuntu 20.04 / 22.04 / 24.04), x86_64
- **Python**: 3.8 - 3.12
- **Hardware targets**: DX-M1 (`dx_m1`)
- **Quantization**: EMA 또는 MinMax calibration을 통한 INT8
- **PPU types**: Type 0 (anchor-based: YOLOv3/v4/v5/v7), Type 1 (anchor-free: YOLOX, YOLOv8-v12)
- **Compilation flow**: ONNX + config.json + calibration data → .dxnn
- **두 가지 인터페이스**: CLI (`dxcom`)와 Python API (`dx_com.compile()`)
