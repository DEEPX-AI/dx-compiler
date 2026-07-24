# DEEPX Agent-Driven Development for DX-COM - dx-agent-dev (Beta)

> **Beta 기능** — 에이전틱 개발 지원은 현재 활발히 개발 중입니다.
> 스킬 정의와 라우팅 동작은 릴리스마다 변경될 수 있습니다.

## 소개

자연어 지시만으로 ONNX 모델을 DXNN 포맷으로 컴파일할 수 있습니다. AI 코딩 에이전트가
DX-COM 컴파일 파이프라인 — config.json 생성, 캘리브레이션 데이터 준비, 양자화 전략,
PPU 설정 — 을 이해하고 있어서, *무엇을* 원하는지 설명하면 에이전트가 구현 세부사항을
처리해줍니다.

지원하는 워크플로우:

- PyTorch 모델을 ONNX로 내보내기 (opset 및 shape 자동 설정)
- DX-COM CLI 또는 Python API를 통한 ONNX → DXNN INT8 양자화 컴파일
- 엔드투엔드 파이프라인: PT → ONNX → DXNN (캘리브레이션 및 검증 포함)

## 사전 요구사항

| 요구사항 | 상세 |
|---|---|
| **DX-COM** | [DX-COM 설치 가이드](02_02_Installation_of_DX-COM.md)를 통해 설치 (`pip install dx-com` 또는 DEEPX 패키지 저장소) |
| **AI 코딩 에이전트** (택 1) | Claude Code, GitHub Copilot (VS Code), Cursor, 또는 OpenCode |
| **Python** | 3.8–3.12 |
| **ONNX** | opset 11–21 |
| **OS** | Debian Linux (Ubuntu 20.04/22.04/24.04), x86_64 |

## 아키텍처 개요

dx-compiler의 에이전틱 지식 베이스는 단일 `.deepx/` 디렉터리에 정리되어 있으며,
에이전트가 작업 시 자동으로 읽는 agents, skills, instructions, toolsets, memory
파일을 포함합니다.

### 컴파일 파이프라인

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

### 주요 제약사항

- 배치 크기는 반드시 1이어야 합니다
- 입력 shape은 정적이어야 합니다 (동적 축 불가)
- ONNX opset: 11–21
- 다중 입력 모델: Python API만 지원 (CLI 불가)

> **참고:** 대상 디바이스는 항상 DX-M1입니다 — 에이전트는 하드웨어 선택에 대해 질문하지 않아야 합니다.

## 에이전트 및 스킬

### 에이전트

| 에이전트 | 설명 |
|---|---|
| `@dx-compiler-builder` | 마스터 라우터 — 작업을 분류하고 전문 에이전트로 라우팅 |
| `@dx-model-converter` | PyTorch 모델을 ONNX 포맷으로 변환 |
| `@dx-dxnn-compiler` | DX-COM을 사용하여 ONNX 모델을 DXNN으로 컴파일 |

### 스킬 (모든 플랫폼)

#### 범용 SWE 프로세스

| 스킬 | 설명 |
|------|------|
| `/dx-swe-brainstorm` | 컴파일 작업 전 브레인스토밍 및 계획 수립 |
| `/dx-swe-tdd` | 테스트 주도 개발 — 각 단계별 점진적 검증 |
| `/dx-swe-verify` | 완료 선언 전 검증 — 증거 기반 확인 |
| `/dx-swe-writing-plans` | 스펙 또는 요구사항으로부터 구현 계획 작성 |
| `/dx-swe-executing-plans` | 리뷰 체크포인트가 포함된 구현 계획 실행 |
| `/dx-swe-debugging` | 수정 제안 전 체계적 디버깅 |
| `/dx-swe-parallel-agents` | 독립 작업을 병렬 에이전트로 디스패치 |
| `/dx-swe-subagent-dev` | 독립 서브 에이전트를 활용한 계획 실행 |
| `/dx-swe-receiving-review` | 코드 리뷰 피드백 수신 및 처리 |
| `/dx-swe-requesting-review` | 병합 전 코드 리뷰 요청 |
| `/dx-skill-router` | 적절한 스킬로 작업 라우팅 |

#### DEEPX 빌드

| 스킬 | 설명 |
|------|------|
| `/dx-agent-compiler-compile` | ONNX → DXNN 컴파일 단계별 워크플로우 |
| `/dx-agent-compiler-convert` | PyTorch → ONNX 변환 단계별 워크플로우 |
| `/dx-agent-compiler-validate` | 컴파일된 .dxnn 모델 출력 검증 |

## 지원하는 AI 도구

에이전틱 개발은 다섯 가지 AI 코딩 도구에서 사용할 수 있습니다. 각 도구는 자체
설정 메커니즘을 통해 `.deepx/` 지식 베이스를 자동으로 로드합니다.

| 도구 | 유형 | 자동 로드 방식 | 에이전트 호출 방법 |
|---|---|---|---|
| **Claude Code** | CLI | 프로젝트 루트의 `CLAUDE.md` | 자유 대화; Context Routing Table이 자동 디스패치 |
| **GitHub Copilot** | VS Code | `.github/copilot-instructions.md` | Copilot Chat에서 `@dx-compiler-builder "프롬프트"` |
| **Cursor** | IDE | `.cursor/rules/` (19개 파일: `dx-compiler.mdc`, 에이전트 `.mdc` 3개, `skill-*.mdc` 15개) | 자유 대화; `alwaysApply` 규칙이 자동 로드 |
| **OpenCode** | CLI | `AGENTS.md` + `opencode.json` | `@dx-compiler-builder "프롬프트"` 또는 `/dx-agent-compiler-compile` |
| **Codex CLI** | CLI | `AGENTS.md` + `.codex/skills/dx-codex-identity/SKILL.md` | `codex` / `codex exec` 기반 자유 대화; 필요 시 `.deepx/skills/*/SKILL.md`를 직접 확인 |

### 처음 사용할 때

추가 설정이 필요 없습니다. 원하는 도구로 `dx-compiler/` 디렉터리를 열면
설정 파일이 자동으로 로드됩니다:

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

# GitHub Copilot — VS Code에서 폴더 열기
code dx-all-suite/dx-compiler

# Cursor — Cursor에서 폴더 열기
cursor dx-all-suite/dx-compiler
```

### 플랫폼별 파일 참조

각 AI 코딩 에이전트는 dx-compiler 레벨에서 서로 다른 설정 파일을 자동 로딩합니다.

#### 자동 로딩 파일

| 파일 | 자동 로드 주체 | 로딩 |
|------|----------------|------|
| `.github/copilot-instructions.md` | Copilot Chat/CLI | Auto |
| `CLAUDE.md` | Claude Code | Auto |
| `AGENTS.md` + `opencode.json` | OpenCode | Auto |
| `.cursor/rules/` (19개 파일) | Cursor | Auto |
| `AGENTS.md` + `.codex/skills/dx-codex-identity/SKILL.md` | Codex CLI | Auto |

#### 에이전트 파일 (수동 @mention)

| 에이전트 | Copilot (`@mention`) | Claude Code (`@mention`) | OpenCode (`@mention`) |
|----------|------|---------|---------|
| `dx-compiler-builder` | `.github/agents/dx-compiler-builder.agent.md` | `.claude/agents/dx-compiler-builder.md` | `.opencode/agents/dx-compiler-builder.md` |
| `dx-dxnn-compiler` | `.github/agents/dx-dxnn-compiler.agent.md` | `.claude/agents/dx-dxnn-compiler.md` | `.opencode/agents/dx-dxnn-compiler.md` |
| `dx-model-converter` | `.github/agents/dx-model-converter.agent.md` | `.claude/agents/dx-model-converter.md` | `.opencode/agents/dx-model-converter.md` |

> **Codex CLI 참고:** Codex는 여기서 `@mention` 에이전트 wrapper를 사용하지 않습니다.
> `AGENTS.md`를 자동으로 읽고, 더 깊은 grounding이 필요하면 `.deepx/agents/*.md`
> 또는 `.deepx/skills/*/SKILL.md`를 직접 참조합니다.

#### 스킬 파일 (모든 플랫폼)

스킬은 모든 플랫폼에 존재합니다:

- `.deepx/skills/` — 정식 정의 (15개 스킬)
- `.github/skills/` — Copilot 인라인 사본
- `.claude/skills/` — Claude 씬 래퍼
- `.opencode/agents/` — OpenCode, 스킬 참조를 통해
- `.cursor/rules/skill-*.mdc` — Cursor 규칙
- `.codex/skills/dx-codex-identity/` — Codex 자동 로드 identity wrapper; 작업별 스킬은 `.deepx/skills/`에서 직접 읽음

| 스킬 | 파일 |
|------|------|
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

#### 공유 지식 베이스 (`.deepx/`)

`.deepx/` 디렉토리는 모든 플랫폼별 파일의 **정식 소스(canonical source)**입니다. `dx-agent-gen` 생성기가 에이전트, 스킬, 템플릿을 Copilot (`.github/`), Claude Code (`.claude/`), OpenCode (`.opencode/`), Cursor (`.cursor/rules/`)용 플랫폼별 파일로 변환합니다. 런타임 지식 파일(memory, instructions, toolsets)은 작업 실행 중 에이전트가 필요 시 읽습니다.

| 디렉토리 | 파일 | 설명 |
|-----------|------|------|
| `.deepx/agents/` | `dx-compiler-builder.md`, `dx-dxnn-compiler.md`, `dx-model-converter.md` | 에이전트 원본 정의 — `dx-agent-gen`이 `.github/agents/`, `.claude/agents/`, `.opencode/agents/`, `.cursor/rules/`로 플랫폼 사본을 생성 |
| `.deepx/templates/` | `{en,ko}/*.tmpl` | 인스트럭션 파일 템플릿 (상위 디렉토리 탐색을 통한 프래그먼트, 스위트 루트까지) |
| `.deepx/toolsets/` | `dxcom-api.md`, `dxcom-cli.md`, `config-schema.md` | API 및 CLI 레퍼런스 |
| `.deepx/instructions/` | `coding-standards.md`, `compilation-workflow.md` | 코딩 규칙 및 워크플로우 |
| `.deepx/memory/` | `common_pitfalls.md`, `MEMORY.md` | 영구 지식 — 공통 실수 및 세션 메모리 |

#### 생성 파이프라인

모든 플랫폼별 파일(`.github/`, `.claude/`, `.opencode/`, `.cursor/rules/`)은 `dx-agent-gen`이 `.deepx/`로부터 생성합니다:

```bash
dx-agent-gen generate --repo dx-compiler
```

pre-commit 훅이 `.deepx/` 소스와 생성된 플랫폼 파일 간의 차이를 감지합니다. **플랫폼 파일을 직접 편집하지 마세요** — 항상 정식 `.deepx/` 소스를 편집하고 생성기를 다시 실행하세요.

## 사용 시나리오

### 필수 브레인스토밍 질문

컴파일 작업 시작 전, 에이전트는 올바른 설정을 위해 세 가지 필수 질문을 합니다.
이 질문들은 건너뛸 수 없습니다.

#### Q1: NMS-Free 모델 감지 (PT → ONNX 작업)

YOLO 모델의 경우, 에이전트가 NMS-free 기능을 자동 감지하고 각 버전(v3~v26)별로
앵커 타입, NMS-free 지원 여부, PPU 타입을 보여주는 YOLO 버전 특성 테이블을 표시합니다.
권장 내보내기 모드는 모델의 NMS-free 아키텍처에 따라 다릅니다:

- **NMS-free 모델** (YOLOv10, YOLO26): **end2end=True** (권장) — 네이티브
  NMS-free 출력 `[1, 300, 6]`, 후처리 불필요. 이 모델들은 one-to-one 매칭을
  기본적으로 사용합니다.
- **선택적 NMS-free 모델** (YOLOv8, v9, v11, v12): **end2end=False** (권장, 기본값)
  — 퓨즈된 출력 `[1, 84, 8400]`, NMS 후처리 필요하지만 NMS 파라미터를 완전히
  제어할 수 있습니다.

#### Q2: ONNX 단순화

기본값은 OFF입니다. 에이전트가 장점(그래프 정리, 모델 크기 감소)과 단점(수치 정밀도 손실,
디버깅 어려움, 모델 손상 위험, 입력 이름 변경)을 설명합니다. 사용자가 내보내기 후
`onnx-simplifier` 실행 여부를 확인합니다.

#### Q3: PPU 컴파일 지원 (ONNX → DXNN 작업)

탐지 모델의 경우, 에이전트가 PPU 적격성을 자동 감지하고 트레이드오프를 설명합니다:

- **PPU 미사용** (기본값) — 추론 시 NMS 파라미터를 자유롭게 제어 가능
- **PPU 사용** — 후처리가 하드웨어에서 실행되어 배포가 간단해짐

PPU를 활성화하면, 에이전트가 모델 계열에 따라 PPU 타입을 자동 추론합니다
(앵커 기반 YOLOv3~v7은 type 0, 앵커 프리 YOLOv8+는 type 1).

### 시나리오 1: PyTorch 모델을 ONNX로 변환

**프롬프트:**

```
"내 yolo26x-custom.pt를 opset 17, 입력 크기 [1, 3, 640, 640]으로 ONNX로 변환해줘"
```

| 도구 | 사용 방법 |
|---|---|
| **Claude Code** | `dx-compiler/`를 열고 프롬프트를 바로 입력합니다. |
| **GitHub Copilot** | `@dx-model-converter` 뒤에 프롬프트를 입력합니다. |
| **Cursor** | `dx-compiler/`를 열고 프롬프트를 입력합니다. |
| **OpenCode** | `/dx-agent-compiler-convert` 또는 `@dx-model-converter` 뒤에 프롬프트를 입력합니다. |

### 시나리오 2: ONNX를 DXNN으로 컴파일

**프롬프트:**

```
"model.onnx를 ./calibration_images/에서 EMA 캘리브레이션 200장으로 INT8 양자화해서 DXNN으로 컴파일해줘"
```

| 도구 | 사용 방법 |
|---|---|
| **Claude Code** | `dx-compiler/`를 열고 프롬프트를 바로 입력합니다. |
| **GitHub Copilot** | `@dx-dxnn-compiler` 뒤에 프롬프트를 입력합니다. |
| **Cursor** | `dx-compiler/`를 열고 프롬프트를 입력합니다. |
| **OpenCode** | `/dx-agent-compiler-compile` 또는 `@dx-dxnn-compiler` 뒤에 프롬프트를 입력합니다. |

### 시나리오 3: 전체 파이프라인 PT → DXNN

**프롬프트:**

```
"내 yolo26x-custom.pt를 DX-M1용 DXNN으로 변환해줘"
```

| 도구 | 사용 방법 |
|---|---|
| **Claude Code** | `dx-compiler/`를 열고 프롬프트를 입력합니다. 라우터 에이전트가 변환과 컴파일을 모두 관리합니다. |
| **GitHub Copilot** | `@dx-compiler-builder` 뒤에 프롬프트를 입력합니다. |
| **Cursor** | `dx-compiler/`를 열고 프롬프트를 입력합니다. |
| **OpenCode** | `@dx-compiler-builder` 뒤에 프롬프트를 입력합니다. |

## Config 자동 추론

모델과 캘리브레이션 데이터를 제공하면 에이전트가 자동으로 추론합니다:

| 필드 | 자동 추론 근거 |
|---|---|
| `inputs` shape | ONNX 모델 메타데이터 (`onnx.load()` → `graph.input`) |
| `calibration_method` | 기본값 `ema` (대부분의 모델에 권장) |
| `preprocessings.resize` | 입력 shape의 차원 (H, W) |
| `preprocessings.normalize` | 모델 계열 (분류 모델은 ImageNet 기본값, YOLO는 [0,1]) |
| `ppu.type` | 모델 아키텍처 (앵커 기반은 0, 앵커 프리는 1) |
| `ppu.num_classes` | ONNX 출력 shape 분석 |

## 출력 격리

모든 컴파일 산출물은 기본적으로 `dx-agent-dev/<session_id>/`에 저장됩니다.
각 컴파일 세션이 자체 완결적이고 재현 가능하도록 합니다.

**세션 ID 형식**: `YYYYMMDD-HHMMSS_<agent>_<model>_<task>` — `<agent>`는 `claude`, `codex`, `copilot`, `cursor`, `opencode` 중 하나

| 출력 유형 | 경로 | 조건 |
|---|---|---|
| **기본 (격리)** | `dx-agent-dev/<session_id>/` | 사용자가 별도 지정하지 않으면 항상 |
| **사용자 지정** | `-o` 옵션으로 지정한 경로 | 명시적으로 요청했을 때 |

**컴파일 후 작업 디렉토리 내용**:
```
dx-agent-dev/<session_id>/
├── calibration_dataset   → ../../dx_com/calibration_dataset/ (심볼릭 링크)
├── config.json           (자동 생성)
├── model.onnx            (입력 또는 변환됨)
├── model.dxnn        (컴파일 출력)
├── compiler.log          (컴파일 로그)
├── detect_model.py       (추론 애플리케이션)
├── verify.py             (ONNX vs DXNN 검증)
├── setup.sh              (환경 셋업)
├── run.sh                (추론 실행기)
└── README.md             (파일 목록 포함 세션 리포트)
```

## 캘리브레이션 데이터셋 관리

에이전트가 캘리브레이션 데이터를 자동으로 관리합니다:

1. `dx_com/calibration_dataset/` 존재 여부 확인 (100장 JPEG)
2. 없으면 `example/2-download_sample_calibration_dataset.sh` 실행
3. 세션 작업 디렉토리에 심볼릭 링크 생성
4. config.json에서 상대경로 `./calibration_dataset` 사용 (절대경로 사용 금지)

## 샘플 모델 워크플로우

`example/` 디렉토리에 사전 빌드된 샘플 모델로 컴파일 파이프라인을 테스트할 수 있는
3단계 워크플로우가 있습니다:

```bash
cd dx-compiler
./example/1-download_sample_models.sh      # ONNX + JSON 설정 다운로드
./example/2-download_sample_calibration_dataset.sh  # 캘리브레이션 데이터셋 다운로드
./example/3-compile_sample_models.sh       # 모든 샘플 모델을 .dxnn으로 컴파일
```

**샘플 모델 목록**: YOLOV5S-1, YOLOV5S_Face-1, MobileNetV2-1

다운로드된 JSON 설정 파일은 새 모델의 config.json을 생성할 때 표준 참조 역할을 합니다
— 올바른 입력 이름 지정, 전처리 파라미터, 캘리브레이션 설정, PPU 설정 방법을 보여줍니다.

## 세션 센티넬

에이전트는 자동화 테스트를 위해 각 작업의 시작과 끝에 고정 마커를 출력합니다:

| 마커 | 출력 시점 |
|---|---|
| `[DX-AGENT-DEV: START]` | 에이전트 응답의 첫 줄 |
| `[DX-AGENT-DEV: DONE (output-dir: <relative_path>)]` | 모든 작업 완료 후 마지막 줄. `<relative_path>`는 프로젝트 루트 기준 세션 출력 디렉터리의 상대 경로입니다. 파일이 생성되지 않은 경우 `(output-dir: ...)` 부분을 생략합니다. |

규칙:

1. **필수** — 첫 번째 응답의 절대적 첫 줄에 `[DX-AGENT-DEV: START]`를 출력합니다. 다른 텍스트, tool call, reasoning보다 반드시 먼저 출력해야 합니다. 사용자가 "알아서 진행해"라고 해도 생략 불가 — 자동 테스트가 실패합니다.
2. 모든 작업 완료 후 맨 마지막 줄에 `[DX-AGENT-DEV: DONE (output-dir: <path>)]`를 출력합니다.
3. 핸드오프로 호출된 하위 에이전트는 센티넬을 출력하지 않으며, 최상위 에이전트만 출력합니다.
4. 사용자가 세션에서 여러 프롬프트를 보내면, 각 프롬프트마다 START/DONE을 출력합니다.
5. DONE의 `output-dir`은 프로젝트 루트에서 세션 출력 디렉터리까지의 상대 경로여야 합니다.
6. **기획 산출물(spec, plan, 설계 문서)만 작성한 상태에서는 절대 DONE을 출력하지 마세요.** DONE은 모든 산출물(구현 코드, 스크립트, 설정 파일, 검증 결과)이 생성된 후에만 출력합니다.

## 문제 해결

| 증상 | 원인 | 해결 방법 |
|---|---|---|
| `ValueError: Batch size must be 1` | 모델의 배치가 1이 아님 | batch=1 입력 shape으로 ONNX를 다시 내보내세요 |
| config.json inputs에서 `KeyError` | 입력 이름이 ONNX 모델과 불일치 | `onnx.load(model).graph.input[0].name`으로 정확한 이름을 확인하세요 |
| 캘리브레이션 단계에서 컴파일이 멈춤 | 캘리브레이션 이미지가 부족하거나 파일 확장자가 잘못됨 | `dataset_path`가 존재하고 `file_extensions`에 맞는 이미지가 있는지 확인하세요 |
| 컴파일 후 정확도가 낮음 | 캘리브레이션 데이터가 대표성이 부족함 | 실제 추론 이미지를 사용하고 `calibration_num`을 200 이상으로 늘리세요 |
| `ONNX opset not supported` | opset이 11 미만이거나 21 초과 | `opset_version=17`로 다시 내보내세요 (권장) |
| PPU 출력 포맷 불일치 | 모델 아키텍처에 맞지 않는 PPU type | YOLOv3/v4/v5/v7은 type=0, YOLOX/v8/v9/v10/v11/v12는 type=1을 사용하세요 |
| ONNX 출력이 1개가 아닌 6개 | Ultralytics YOLO `Detect.export` 플래그 미설정 | `model.export(format="onnx")`를 사용하거나 `torch.onnx.export()` 전에 `Detect.export=True`를 설정하세요. `.deepx/memory/common_pitfalls.md`의 Pitfall #10 참조 |
| 추론 결과의 클래스 라벨이 틀림 | 후처리 클래스 인덱스 불일치 | `verify.py`로 ONNX vs DXNN 출력 비교. COCO 클래스 0-indexed vs 1-indexed 확인 |
| 컴파일된 모델에서 검출 안됨 | 생성된 앱의 후처리 버그 | `verify.py` 실행. 출력 텐서 shape 파싱 및 confidence threshold 확인 |

## 필수 출력 산출물

추론 애플리케이션을 생성하는 모든 컴파일 세션에서 반드시 다음 배포 산출물을
세션 디렉토리에 함께 생성해야 합니다:

| 산출물 | 용도 |
|---|---|
| `setup.sh` | `sanity_check.sh`로 dx-runtime 설치 확인, 미설치 시 `install.sh`로 자동 설치; dxcom 미설치 시 `dx-compiler/install.sh`로 설치; 가상환경 생성, dx_engine, opencv-python, numpy, onnxruntime 설치 |
| `run.sh` | 한 줄 명령어로 추론 실행 (모델 태스크에 맞는 샘플 이미지 경로 포함) |
| `README.md` | 세션 요약: 파이프라인, 생성된 파일, 빠른 시작, 환경 정보 |
| `verify.py` | ONNX vs DXNN 추론 비교 — 후처리 버그 검출 |

컴파일 직후 `bash setup.sh && bash run.sh`만으로 수동 설정 없이 바로 실행할 수
있어야 합니다.

## TDD 검증 게이트

최종 컴파일 보고서를 제시하기 전, 에이전트가 `verify.py`를 실행하여 ONNX 추론
(정답 기준)과 DXNN 추론 출력을 비교합니다:

- `dx-runtime/dx_app/sample/`에서 모델 태스크에 맞는 샘플 이미지 사용:
  - 객체 감지: `img/sample_dog.jpg`, `img/sample_horse.jpg`
  - 얼굴 감지: `img/sample_face.jpg`, `img/sample_crowd.jpg`
  - 포즈 추정: `img/sample_people.jpg` | 손 감지: `img/sample_hand.jpg`
  - OBB: `dota8_test/P0177.png` | 세그멘테이션: `img/sample_street.jpg`
  - 분류: `ILSVRC2012/0.jpeg` | 초해상도: `img/sample_superresolution.png`
  - 저조도: `img/sample_lowlight.jpg` | 노이즈 제거: `img/sample_denoising.jpg`
- 검출 수 비교 (20% 이내), 클래스 라벨 비교 (상위 K개 일치), bbox IoU 비교 (평균 > 0.5)
- **PASS** → 컴파일 및 추론 앱이 정상
- **FAIL** → 후처리 버그 존재; 에이전트가 디버깅 후 수정하여 성공할 때까지 재검증

이 게이트는 실제 테스트에서 발견된 문제에 기반합니다 — 컴파일된 모델이 벤치마크에서
정상 (예: 139 FPS)이지만, 생성된 추론 애플리케이션이 후처리 버그(잘못된 클래스 매핑,
부정확한 bbox 디코딩)로 인해 잘못된 결과를 출력하는 경우가 있었습니다.
