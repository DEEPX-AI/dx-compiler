# DEEPX DX-COM 컴파일러 — Claude Code 진입점

> Claude Code / OpenCode를 위한 자체 완결형 진입점. 이 파일을 먼저 읽으세요.

## 응답 언어

사용자의 프롬프트 언어에 맞춰 응답하세요 — 질문하거나 응답할 때
사용자가 사용하는 언어와 동일한 언어를 사용하세요.

**기술 용어 규칙**: 한국어로 응답할 때 영어 기술 용어는 원래 영어 형태를 유지하세요.
영어 용어를 한글 음차로 표기하지 마세요 (한글 음차 표기 금지).
정착된 한국어 외래어 (모델, 서버, 파일, 데이터)는 사용 가능합니다.

## 권장 모델 (사전 점검)

DX Agentic Development는 강력한 지시 따르기와 지식 베이스 활용이 필요합니다.
작업을 시작하기 전에, 다음 권장 모델 중 하나로 실행 중인지 확인하세요:

- **Claude Sonnet 4.6** 이상
- **Claude Opus 4.6** 이상

이 모델이 아닌 경우 (예: GPT-4.1, GPT-4o, Gemini 등),
첫 번째 응답 시작 부분에 다음 안내를 출력하세요:

```
══════════════════════════════════════════════════════════════
⚠  DX-AGENTIC-DEV: MODEL NOTICE

DX Agentic Development recommends Claude Sonnet 4.6+ or
Opus 4.6+. Your current model may produce lower quality
in instruction following, knowledge base utilization, and
API accuracy. Please switch to a recommended model.
══════════════════════════════════════════════════════════════
```

박스 안내 이후, 정상적으로 작업을 진행하세요. 이것은 정보 제공 목적의
경고이며, 차단 게이트가 아닙니다.

### 모델 안내 반복 (비권장 모델만 해당)

위의 MODEL NOTICE 박스를 출력한 경우 (즉, 권장 모델이 아닌 경우),
사용자가 답해야 하는 **실제 질문 줄 바로 앞에** 이 축약된 리마인더를
출력해야 합니다 — 브레인스토밍 흐름의 시작 부분이 아닙니다.

**타이밍**: 모든 파일 읽기, 컨텍스트 분석, 서문 텍스트 이후,
`?` (실제 질문)가 포함된 줄 바로 앞에 이 리마인더를 삽입하세요:

```
---
⚠ **Non-recommended model** — output quality may be degraded. Recommended: Claude Sonnet 4.6+ / Opus 4.6+
---
```

**예시 — 잘못됨** (반복이 박스와 함께 스크롤되어 지나감):
```
[DX-AGENTIC-DEV: START]
══ MODEL NOTICE ══
---  ⚠ Non-recommended model ---     ← 너무 이른 위치, 스크롤되어 지나감
... (파일 읽기, 컨텍스트 분석) ...
첫 번째 질문: ...?
```

**예시 — 올바름** (반복이 질문 바로 앞에 표시됨):
```
[DX-AGENTIC-DEV: START]
══ MODEL NOTICE ══
... (파일 읽기, 컨텍스트 분석) ...
---  ⚠ Non-recommended model ---     ← 질문 바로 앞
첫 번째 질문: ...?
```

이 리마인더는 한 번만 (첫 번째 질문 앞에) 출력하세요. 매 질문마다 출력하지 마세요.

## 공유 지식

모든 스킬, 지시사항, 도구셋, 메모리는 `.deepx/`에 있습니다.
전체 마스터 인덱스는 `.deepx/README.md`를 읽으세요.

## 핵심 규칙: 모델 획득 및 엔드투엔드 컴파일

**필수**: 사용자가 모델 컴파일을 요청하고 로컬 `.pt`, `.pth`, 또는 `.onnx` 파일
경로를 제공하지 않는 경우, 에이전트는 반드시:

1. 요청된 모델의 **공식 다운로드 소스를 확인**
2. 세션 작업 디렉토리에 모델 파일을 **실제로 다운로드**
3. 전체 파이프라인을 통해 모델을 **실제로 컴파일** (PT→ONNX→DXNN 또는 ONNX→DXNN)
4. **실제 `.dxnn` 출력 파일을 생성**

`config.json`만 생성하거나 컴파일 지시사항만 제공하고 **절대 멈추지 마세요**.
사용자는 레시피가 아니라 컴파일된 `.dxnn` 모델을 기대합니다.

### 모델 다운로드 소스 (우선순위 순서)

| 모델 패밀리 | 소스 | 다운로드 방법 |
|---|---|---|
| Ultralytics YOLO (v5-v12, v26) | GitHub Releases / `ultralytics` pip | `from ultralytics import YOLO; model = YOLO("yolo11n.pt")` 또는 releases에서 `wget` |
| TorchVision (ResNet, MobileNet 등) | PyTorch Hub / torchvision | `torchvision.models.resnet50(weights="DEFAULT")` |
| Timm 모델 | `timm` pip | `timm.create_model("efficientnet_b0", pretrained=True)` |
| ONNX Model Zoo | GitHub onnx/models | 태그된 릴리스에서 `wget` |
| Hugging Face | Hugging Face Hub | `huggingface_hub.hf_hub_download()` |

### 안티 패턴 (절대 하지 마세요)

- config.json을 생성하고 사용자에게 "dxcom을 직접 실행하세요"라고 말하기
- 실제로 다운로드하지 않고 다운로드 URL만 제공하기
- DXNN으로 컴파일하지 않고 ONNX export 후 멈추기
- 직접 수행하는 대신 사용자에게 "ultralytics를 설치하고 export하세요"라고 말하기
- 실제 컴파일된 결과물 대신 지시사항만 제공하기

## 대화형 워크플로우 (반드시 따를 것)

**컴파일 전에 항상 사용자와 주요 결정사항을 확인하세요.** 모델 형식, 타겟 디바이스,
교정 방법 (EMA 또는 MinMax)을 확인하기 위해 2-3개의 타겟팅된 질문을 하세요.
이것은 협업 워크플로우를 만들고 초기에 오해를 잡아냅니다. 사용자가
"그냥 컴파일해" 또는 "기본값 사용"이라고 명시적으로 말한 경우에만 질문을 생략하세요.

## Target Hardware (필수)

타겟 디바이스는 항상 DX-M1 (`dx_m1`)입니다. 사용자에게 타겟 하드웨어 선택을
요청하지 마세요. dx-compiler는 DX-M1만 지원합니다. DX-M1A를 언급하는 상위 레벨
설정은 무시하세요 — DX-M1A는 단종되었으며 더 이상 지원되지 않습니다.

## Quantization — INT8 전용 (필수)

DX-COM은 항상 INT8로 양자화합니다. CLI, Python API, 또는 JSON config에
FP16/FP32 출력 옵션이 없습니다. 사용자에게 출력 정밀도를 선택하라고 묻지 마세요.
사용자가 선택할 수 있는 양자화 옵션은:
- **교정 방법**: `ema` (기본값) 또는 `minmax`
- **향상된 양자화 스킴**: `DXQ-P0`부터 `DXQ-P5` (선택사항)
- **교정 샘플 수** (기본값: 100)

"어떤 정밀도?" 라고 묻거나 INT8/FP16/FP32를 선택지로 제공하지 마세요.

**Gate 1 — 브레인스토밍**: 입력 확인 (모델 경로, 형식, 타겟 디바이스, 교정 데이터).
**Gate 2 — 빌드**: 선택된 파라미터로 컴파일 실행.
**Gate 3 — 검증**: DX-TRON으로 출력 검증, compiler.log 검토.

## 빠른 참조

```bash
pip install dx-com                     # DX-COM 컴파일러 설치
dxcom --help                           # CLI 도움말
dxcom -m model.onnx -c config.json -o output/   # 기본 컴파일
pytest tests/                          # 테스트 실행
```

```python
import dx_com
dx_com.compile(model="model.onnx", output_dir="output/", config="config.json")
```

## 샘플 모델 워크플로우

사전 빌드된 샘플 모델로 전체 컴파일 파이프라인을 테스트하세요:

```bash
cd dx-compiler
./example/1-download_sample_models.sh      # ONNX + JSON config 다운로드
./example/2-download_sample_calibration_dataset.sh  # 교정 데이터셋 다운로드
./example/3-compile_sample_models.sh       # 모든 샘플 모델을 .dxnn으로 컴파일
```

샘플 모델: YOLOV5S-1, YOLOV5S_Face-1, MobileNetV2-1.
다운로드된 JSON config는 새 모델의 config.json을 생성할 때 표준 참조로 사용됩니다
— 유사한 모델 타입의 샘플 JSON을 읽으세요.

## 스킬

| 명령 | 설명 |
|---------|-------------|
| `/dx-convert-model` | PyTorch 모델을 ONNX로 변환 |
| `/dx-compile-model` | ONNX 모델을 DXNN으로 컴파일 |
| `/dx-validate-compile` | 컴파일 출력 검증 |
| `/dx-brainstorm-and-plan` | 프로세스: 컴파일 전 협업 설계 세션 |
| `/dx-tdd` | 프로세스: 테스트 주도 개발 — 각 단계를 점진적으로 검증 |
| `/dx-verify-completion` | 프로세스: 완료 선언 전 검증 — 주장 전에 증거 |

## 핵심 규칙

1. **배치 크기는 반드시 1**: DEEPX NPU는 batch=1만 지원
2. **정적 shape만 사용**: 동적 axes 없음, -1 차원 없음
3. **ONNX opset 11-21**: 최상의 호환성을 위해 opset 13 사용
4. **입력 이름 일치**: config.json의 `inputs` 키는 ONNX 입력 이름과 정확히 일치해야 함
5. **대표적 교정**: 교정 이미지는 추론 분포와 일치해야 함
6. **PPU 타입 중요**: Type 0 = anchor-based (YOLOv3-v7), Type 1 = anchor-free (YOLOX, YOLOv8-v12). YOLO26은 PPU를 지원하지 않음.
7. **항상 검증**: 모든 컴파일 후 DX-TRON 검사 실행
8. **하드코딩된 경로 금지**: 모든 경로에 파라미터 또는 환경 변수 사용
9. **자동 simplification 금지**: 사용자가 명시적으로 요청하지 않는 한 `onnx-simplifier`를 실행하지 마세요 — 수치 정밀도 손실, 노드 이름 변경으로 인한 config.json 깨짐, 잠재적 모델 손상 위험
10. **Ultralytics YOLO export**: `Detect.export=True`를 설정하거나 `model.export(format="onnx")`를 사용해야 함 — 표준 `torch.onnx.export()`는 1개가 아닌 6개의 출력을 생성. export 후 ONNX에 정확히 1개의 출력 노드가 있는지 항상 확인.
11. **필수 브레인스토밍 질문**: 모든 컴파일 작업 전에 에이전트는 반드시 세 가지 필수 질문을 해야 함: (Q1) YOLO 버전 특성 테이블과 NMS-free 모델 감지, (Q2) 장단점 설명과 ONNX simplification, (Q3) 하드웨어 vs 유연성 트레이드오프와 PPU 컴파일 지원. 정확한 질문 템플릿은 `.deepx/agents/dx-compiler-builder.md` Step 2 참조.
12. **PPU 기본값은 OFF**: PPU 컴파일은 opt-in. 브레인스토밍 Q3에서 사용자가 명시적으로 확인한 경우에만 config.json에 PPU config 추가. **YOLO26은 PPU를 지원하지 않음** — YOLO26 모델의 경우 Q3 생략 (NMS-free 네이티브 아키텍처).
13. **모델 획득 — 지시가 아닌 다운로드 및 컴파일**: 사용자가 로컬 `.pt`/`.pth`/`.onnx` 파일을 제공하지 않은 경우, 에이전트는 공식 다운로드 소스 (Ultralytics releases, torchvision, timm, ONNX Model Zoo, Hugging Face)를 찾아 실제로 모델을 다운로드하고, 전체 파이프라인을 통해 `.dxnn` 파일을 생성하도록 컴파일해야 합니다. config.json만 생성하거나 컴파일 지시사항을 제공하고 멈추지 절대 마세요.
14. **컴파일 후 검증은 필수 — 검증 없이는 컴파일이 완료되지 않음**: 모든 성공적인 `dxcom` 컴파일 후, 결과를 사용자에게 제시하기 전에 에이전트는 반드시 다음을 모두 완료해야 합니다. 이것 없이 "컴파일 성공" 요약을 절대 제시하지 마세요:
    - **(a)** 출력 디렉토리 (세션 디렉토리 또는 사용자 지정 디렉토리)에 `setup.sh`, `run.sh`, `README.md` 생성
    - **(b)** `verify.py` 생성 — ONNX vs DXNN 추론 비교 스크립트
    - **(c)** `verify.py` 실행 및 PASS 확인 (감지 수 20% 이내, 클래스 일치, IoU > 0.5)
    - **(d)** `${WORK_DIR}/session.log`에 세션 로그 저장 — 손으로 작성한 요약이 아닌 `tee`를 통해 캡처된 **실제 명령 실행 출력**이어야 함
    - **(e)** 최종 요약 테이블에 검증 결과 (PASS/FAIL) 및 모든 결과물 경로 포함
    - 어떤 단계라도 실패하면, 진행하기 전에 디버그하고 수정하세요. `.dxnn` 파일만으로는 납품물이 아닙니다.
    - **사용자가 커스텀 출력 디렉토리를 지정한 경우에도** (예: `dx-agentic-dev/` 대신 소스 디렉토리), 이러한 결과물은 여전히 필수입니다.
15. **이전 세션 결과물 재사용 금지**: `dx-agentic-dev/`의 이전 세션에서 결과물을 확인, 나열, 탐색, 또는 재사용하지 절대 마세요. 각 컴파일 실행은 새로운 타임스탬프로 새 세션 디렉토리를 생성해야 합니다. 이전 세션이 동일한 모델을 컴파일한 경우에도 항상 처음부터 다시 다운로드, 다시 export, 다시 컴파일하세요. `ls dx-agentic-dev/`를 실행하거나 이전 실행의 기존 `.onnx`/`.dxnn` 파일을 확인하지 마세요.
16. **setup.sh에서 venv는 필수**: 생성된 `setup.sh`는 `pip install` 전에 가상 환경을 생성하고 활성화해야 합니다. Ubuntu 24.04+에서는 PEP 668이 시스템 전체 pip 설치를 차단합니다. `${VIRTUAL_ENV:-}` 확인과 함께 `python3 -m venv`를 사용하세요. 생성된 `run.sh`는 venv 활성화를 확인하고 누락 시 자동 활성화하거나 에러를 출력해야 합니다.
17. **사전 컴파일된 참조 모델과의 교차 검증**: 동일한 모델에 대해 사전 컴파일된 DXNN이 `dx-runtime/dx_app/assets/models/`에 존재하는 경우, 사전 컴파일된 모델과 생성된 모델 모두에 대해 verify.py를 실행하세요 (Phase 5.7). 둘 다 실패 → verify.py 버그. 사전 컴파일된 것은 통과하고 생성된 것은 실패 → 컴파일 문제. `.deepx/agents/dx-dxnn-compiler.md` Phase 5.7 참조.
18. **NHWC/NCHW DataLoader 불일치**: dxcom CLI의 기본 dataloader는 NHWC `[1,H,W,C]`로 이미지를 로드합니다. ONNX 모델이 NCHW `[1,C,H,W]`를 기대하는 경우 (대부분의 PyTorch export 모델), CLI 컴파일은 `DataLoaderError: Input shape mismatch`로 실패합니다. **수정**: NCHW 텐서를 생성하는 커스텀 torch DataLoader와 함께 Python API (`dx_com.compile()`)를 사용하세요. `.deepx/memory/common_pitfalls.md` pitfall #18 참조.

## 교차 검증 진단 테이블

| 결과 | 진단 |
|---|---|
| 둘 다 실패 | verify.py 코드 버그 (먼저 verify.py 수정) |
| 사전 컴파일된 것은 통과, 생성된 것은 실패 | 컴파일 문제 (config, 양자화 수정) |
| 둘 다 통과 | 컴파일 정확 |

## 출력 격리

모든 컴파일 결과물은 기본적으로 `dx-agentic-dev/<session_id>/`에 저장됩니다. 각
컴파일 세션은 결과물을 함께 보관하고 덮어쓰기를 방지하기 위해
고유한 작업 디렉토리를 사용합니다.

**세션 ID 형식**: `YYYYMMDD-HHMMSS_<model>_<task>` — 타임스탬프는 반드시
**시스템 로컬 타임존**을 사용해야 합니다 (UTC 아님). Bash에서는 `$(date +%Y%m%d-%H%M%S)`,
Python에서는 `datetime.now().strftime('%Y%m%d-%H%M%S')`를 사용하세요.
`date -u`, `datetime.utcnow()`, 또는 `datetime.now(timezone.utc)`를 사용하지 마세요.

```bash
SESSION_ID="$(date +%Y%m%d-%H%M%S)_yolo26x_onnx_to_dxnn"
WORK_DIR="dx-agentic-dev/${SESSION_ID}"
mkdir -p "${WORK_DIR}"

# 작업 디렉토리에 교정 데이터 심볼릭 링크
ln -sf ../../dx_com/calibration_dataset "${WORK_DIR}/calibration_dataset"

# config.json은 상대 경로 사용: "dataset_path": "./calibration_dataset"
dxcom -m "${WORK_DIR}/model.onnx" -c "${WORK_DIR}/config.json" -o "${WORK_DIR}/"
```

**작업 디렉토리 내용** (컴파일 후):
```
dx-agentic-dev/<session_id>/
├── calibration_dataset   → ../../dx_com/calibration_dataset/ (symlink)
├── config.json
├── model.onnx
├── model.dxnn
├── compiler.log
└── README.md             (세션 보고서)
```

## 교정 데이터셋

교정 데이터는 `dx_com/calibration_dataset/` (100개 JPEG 이미지)에 있습니다. 없는 경우,
`example/2-download_sample_calibration_dataset.sh`를 실행하여 설정하세요.
config.json에서 항상 상대 경로 (`./calibration_dataset`)를 사용하세요. 절대 경로는 사용하지 마세요.

## 컨텍스트 라우팅 테이블

| 작업에 언급된 내용... | 읽을 파일 |
|---|---|
| **PyTorch, PT, export, convert** | `.deepx/agents/dx-model-converter.md`, `.deepx/skills/dx-convert-model.md` |
| **ONNX, compile, DXNN, dxcom** | `.deepx/agents/dx-dxnn-compiler.md`, `.deepx/skills/dx-compile-model.md` |
| **CLI, command line** | `.deepx/toolsets/dxcom-cli.md` |
| **Python API, dx_com.compile** | `.deepx/toolsets/dxcom-api.md` |
| **config, JSON, schema** | `.deepx/toolsets/config-schema.md` |
| **calibration, quantization, INT8** | `.deepx/instructions/compilation-workflow.md` |
| **PPU, YOLO, detection** | `.deepx/toolsets/config-schema.md`, `.deepx/instructions/compilation-workflow.md` |
| **validate, verify, check** | `.deepx/skills/dx-validate-compile.md` |
| **error, fail, bug** | `.deepx/memory/common_pitfalls.md` |
| **sample, example, test compile** | `.deepx/instructions/compilation-workflow.md` (샘플 모델 워크플로우 섹션) |
| **항상 읽기 (모든 작업)** | `.deepx/memory/common_pitfalls.md`, `.deepx/instructions/coding-standards.md` |
| **Brainstorm, plan, design** | `.deepx/skills/dx-brainstorm-and-plan.md` |
| **TDD, validation, incremental** | `.deepx/skills/dx-tdd.md` |
| **Completion, verify, evidence** | `.deepx/skills/dx-verify-completion.md` |

## 플레이스홀더 코드 금지 (필수)

스텁/플레이스홀더 코드를 절대 생성하지 마세요. 여기에는 다음이 포함됩니다:
- 주석 처리된 import: `# from dxnn_sdk import InferenceEngine`
- 가짜 결과: `result = np.zeros(...)`
- TODO 마커: `# TODO: implement actual inference`
- 실제 async 구현 없이 "sync 버전과 유사"

생성된 모든 코드는 지식 베이스의 실제 API를 사용하는 기능적 코드여야 합니다.
필요한 SDK/API를 모르는 경우, 먼저 관련 스킬 문서를 읽으세요.

## 실험적 기능 — 금지

실험적이거나 존재하지 않는 기능을 제안, 제시, 또는 구현하지 마세요. 여기에는 다음이 포함됩니다:
- "웹 기반 비주얼 컴패니언" (web-based visual companion)
- 로컬 URL 기반 다이어그램 뷰어 또는 대시보드
- 사용자가 시각화를 위해 로컬 URL을 열어야 하는 모든 기능
- 현재 도구셋에 존재하지 않는 모든 기능

**Superpowers brainstorming 스킬 오버라이드**: superpowers `brainstorming` 스킬에는
"Visual Companion" 단계 (체크리스트의 step 2)가 포함되어 있습니다. 이 단계는
DEEPX 프로젝트에서 반드시 건너뛰어야 합니다. 우리 환경에는 visual companion이
존재하지 않습니다. 브레인스토밍 체크리스트에서 "Offer visual companion"이라고 하면,
건너뛰고 "Ask clarifying questions" (step 3)로 바로 진행하세요.

기능이 존재하지 않으면, 존재하는 것처럼 행동하지 마세요. 검증되고 문서화된
기능만 사용하세요.

**Autopilot / 자율 모드 오버라이드**: 사용자가 부재한 경우 (autopilot 모드,
자동 응답 "work autonomously", 또는 `--yolo` 플래그), 브레인스토밍 스킬의
"Ask clarifying questions" 단계는 "지식 베이스 규칙에 따라 기본 결정 내리기"로
대체되어야 합니다. `ask_user`를 호출하지 마세요 — 지식 베이스 기본값을 사용하여
브레인스토밍 스펙 작성으로 바로 진행하세요. 이후의 모든 게이트 (스펙 리뷰,
계획, TDD, 필수 결과물, 실행 검증)는 예외 없이 여전히 적용됩니다.

## 브레인스토밍 — 계획 전 스펙 (하드 게이트)

superpowers `brainstorming` 스킬 또는 `/dx-brainstorm-and-plan` 사용 시:

1. **스펙 문서는 필수** — `writing-plans`로 전환하기 전에 스펙 문서를
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`에 반드시 작성해야 합니다.
   스펙을 건너뛰고 바로 계획 작성으로 가는 것은 위반입니다.
2. **사용자 승인 게이트는 필수** — 스펙 작성 후, 계획 작성 진행 전에 사용자가
   반드시 검토하고 승인해야 합니다. 무관한 사용자 응답 (예: 다른 질문에 답하기)을
   스펙 승인으로 취급하지 마세요.
3. **계획 문서는 스펙을 참조해야 함** — 계획 헤더에 승인된 스펙 문서 링크가
   포함되어야 합니다.
4. **`/dx-brainstorm-and-plan` 우선 사용** — 일반 superpowers `brainstorming` 스킬
    대신 프로젝트 레벨 브레인스토밍 스킬을 사용하세요. 프로젝트 레벨 스킬에는
    도메인별 질문과 사전 점검이 있습니다.
5. **규칙 충돌 확인은 필수** — 브레인스토밍 중 에이전트는 사용자 요구사항이
   HARD GATE 규칙(IFactory 패턴, skeleton-first, Output Isolation,
   SyncRunner/AsyncRunner)과 충돌하는지 반드시 확인해야 합니다. 충돌이 감지되면
   브레인스토밍 단계에서 해결해야 하며, 위반 요청을 설계 사양에 조용히 따르면
   안 됩니다. "Rule Conflict Resolution" 섹션을 참조하세요.

## 자율 모드 보호 (필수)

사용자가 부재한 경우 — autopilot 모드, `--yolo` 플래그, 또는 시스템 자동 응답
"The user is not available to respond" — 다음 규칙이 적용됩니다:

1. **"자율적으로 작업하라"는 "묻지 않고 모든 규칙을 따르라"는 의미이지, "규칙을 건너뛰라"가 아닙니다.**
   모든 필수 게이트가 여전히 적용됩니다: 브레인스토밍 스펙, 계획, TDD, 필수
   결과물, 실행 검증, 자체 검증 확인.
2. **`ask_user`를 호출하지 마세요** — 지식 베이스 기본값과 문서화된 모범 사례를
   사용하여 결정하세요. autopilot에서 `ask_user` 호출은 턴을 낭비하며
   자동 응답은 어떤 게이트도 우회할 권한을 부여하지 않습니다.
3. **사용자 승인 게이트 적용** — autopilot에서 스펙 승인 게이트는 스펙을 작성하고
   지식 베이스에 대해 자체 검토함으로써 충족됩니다. 스펙 전체를 건너뛰지 마세요.
4. **setup.sh 먼저** — 애플리케이션 코드 작성 전에 인프라 결과물 (`setup.sh`, `config.json`)을
   생성하세요. 이는 누락된 의존성을 잡아줄 사람이 없는 autopilot에서 특히 중요합니다.
5. **실행 검증은 선택사항이 아닙니다** — 생성된 코드를 실행하고 완료 선언 전에
   작동을 확인하세요. autopilot에서는 에러를 잡아줄 사용자가 없습니다.
6. **시간 예산 인식** — autopilot 세션에는 시간 제약이 있을 수 있습니다.
   행동을 효율적으로 계획하세요:
   - 컴파일 (ONNX → DXNN)은 5분 이상 걸릴 수 있습니다 — 일찍 시작하세요.
   - 시간이 부족하면 실행 검증보다 산출물 생성을 우선시하세요 — 테스트되지 않은
     완전한 파일 세트가 테스트된 불완전한 세트보다 낫습니다.
   - 우선순위: `setup.sh` > `run.sh` > 앱 코드 > `verify.py` > session.log.
   - **컴파일 병렬 워크플로 (HARD GATE)** — `dxcom` 또는 `dx_com.compile()`을
     bash 명령으로 시작한 후 기다리지 마세요. 즉시 모든 필수 산출물을 생성하세요:
     factory, 앱 코드, setup.sh, run.sh, verify.py. `.dxnn` 출력은 다른 모든
     산출물이 생성된 후에만 확인하세요. **이 규칙 위반 시 세션 실패입니다.**
   - **컴파일 대기를 위한 sleep-poll 금지** — `.dxnn` 파일을 폴링하기 위해
     `sleep`을 루프에서 사용하지 마세요. 금지된 패턴:
     `for i in ...; do sleep N; ls *.dxnn; done`,
     `while ! ls *.dxnn; do sleep N; done`,
     대기 사이에 반복되는 `ls *.dxnn` / `test -f *.dxnn` 확인.
     대신: 다른 모든 산출물을 먼저 생성한 후 `.dxnn` 파일이 존재하는지 한 번만
     확인하세요. 아직 존재하지 않으면 컴파일이 완료될 것이라는 가정하에 실행
     검증으로 진행하세요.
   - **필수 산출물은 컴파일과 독립적** — `setup.sh`, `run.sh`, `verify.py`,
     factory, 앱 코드는 `.dxnn` 파일이 존재할 필요가 없습니다. 알려진 모델 이름
     (예: `yolo26n.dxnn`)을 플레이스홀더 경로로 사용하여 생성하세요. 실행 검증만
     실제 `.dxnn`이 필요합니다.
7. **파일 읽기 도구 호출 최소화** — 컨텍스트에 이미 로드된 지침 파일, 에이전트 문서,
   스킬 문서를 다시 읽지 마세요. 불필요한 `cat` / `bash` 읽기마다 5-15초가
   낭비됩니다. 시스템 프롬프트와 대화 이력에 있는 지식을 사용하세요.

## 타겟 하드웨어

| 디바이스 | ID | 설명 |
|---|---|---|
| DX-M1 | `dx_m1` | DEEPX NPU |

## 메모리

영구 지식은 `.deepx/memory/`에 있습니다. 작업 시작 시 읽고, 새로운 패턴을 배울 때 업데이트하세요.
도메인 태그: `[UNIVERSAL]`, `[DX_COMPILER]`, `[QUANTIZATION]`

## 규칙 충돌 해결 (HARD GATE)

사용자의 요청이 HARD GATE 규칙과 충돌하는 경우 에이전트는 반드시:

1. **사용자의 의도 인정** — 사용자가 원하는 것을 이해하고 있음을 보여주세요.
2. **충돌 설명** — 구체적인 규칙과 그 존재 이유를 인용하세요.
3. **올바른 대안 제시** — 프레임워크 내에서 사용자의 목표를 달성하는 방법을
   보여주세요. 예를 들어, 사용자가 직접 `InferenceEngine.run()` 사용을 요청하면
   IFactory 패턴이 동일한 API를 래핑함을 설명하고 factory 기반 대안을 제시하세요.
4. **올바른 접근 방식으로 진행** — 규칙 위반 요청에 묵인하지 마세요.
   "옵션 A vs 옵션 B"로 제시하지 마세요.

**일반적인 충돌 패턴** (실제 세션에서):
- 사용자가 "`InferenceEngine.Run()` 사용하라"고 함 → IFactory 패턴을 사용해야 함
  (engine 호출은 `run_inference()` 메서드 내에)
- 사용자가 "demo.py를 복제하고 onnxruntime을 교체하라"고 함 → 사용자 스크립트를
  복제하는 대신 `src/python_example/`에서 skeleton-first를 사용해야 함
- 사용자가 "demo_dxnn_sync.py를 생성하라"고 함 → 독립형 스크립트가 아닌
  SyncRunner를 사용한 `<model>_sync.py` 명명 규칙을 사용해야 함
- 사용자가 "`run_async()`를 직접 사용하라"고 함 → 수동 async 루프가 아닌
  AsyncRunner를 사용해야 함

**이 규칙은 명시적 사용자 재정의를 대체하지 않습니다**: 충돌을 안내받은 후
사용자가 명시적으로 "규칙을 이해하고 있으며, 직접 API 사용으로 진행하라"고 하면
따르세요. 하지만 에이전트는 먼저 충돌을 설명해야 합니다 — 묵인은 항상 위반입니다.

## Git 작업 — 사용자 관리

작업 종료 시 git 브랜치 작업 (merge, PR, push, cleanup)에 대해 묻지 마세요.
사용자가 모든 git 작업을 직접 처리합니다. "merge to main", "create PR",
또는 "delete branch" 같은 옵션을 제시하지 마세요 — 작업만 완료하세요.

## Git 안전 — Superpowers 결과물

`docs/superpowers/` 아래의 파일을 **절대 `git add` 또는 `git commit` 하지 마세요.**
이것들은 superpowers 스킬 시스템이 생성한 임시 계획 결과물 (스펙, 계획)입니다.
`.gitignore`에 포함되어 있지만, 일부 도구가 `git add -f`로 `.gitignore`를
우회할 수 있습니다. 파일 생성은 괜찮습니다 — 커밋하는 것은 금지입니다.

## 세션 센티넬 (자동화 테스트 필수)

사용자 프롬프트를 처리할 때, 테스트 하네스의 자동화된 세션 경계 감지를 위해
다음 정확한 마커를 출력하세요:

- **응답의 첫 줄**: `[DX-AGENTIC-DEV: START]`
- **모든 작업 완료 후 마지막 줄**: `[DX-AGENTIC-DEV: DONE (output-dir: <relative_path>)]`
  여기서 `<relative_path>`는 세션 출력 디렉토리입니다 (예: `dx-agentic-dev/20260409-143022_yolo26n_detection/`)

규칙:
1. **중요 — `[DX-AGENTIC-DEV: START]`를 첫 번째 응답의 절대 첫 줄로 출력하세요.**
   다른 텍스트, 도구 호출, 또는 추론보다 앞에 나와야 합니다.
   사용자가 "그냥 진행해" 또는 "네 판단으로 해"라고 지시해도,
   START 센티넬은 비협상 대상입니다 — 없으면 자동화 테스트가 실패합니다.
2. 모든 작업, 검증, 파일 생성이 완료된 후 마지막 줄로 `[DX-AGENTIC-DEV: DONE (output-dir: <path>)]`을 출력하세요
3. 상위 레벨 에이전트로부터 핸드오프/라우팅을 통해 호출된 **서브 에이전트**인 경우,
   이 센티넬을 출력하지 마세요 — 최상위 에이전트만 출력합니다
4. 사용자가 세션에서 여러 프롬프트를 보내면, 각 프롬프트에 대해 START/DONE을 출력하세요
5. DONE의 `output-dir`은 프로젝트 루트에서 세션 출력 디렉토리까지의 상대 경로여야 합니다.
   파일이 생성되지 않은 경우, `(output-dir: ...)` 부분을 생략하세요.
6. **계획 결과물만 생성한 후에는 절대 DONE을 출력하지 마세요** (스펙, 계획, 설계 문서).
   DONE은 모든 납품물이 생성되었음을 의미합니다 — 구현 코드, 스크립트, config,
   검증 결과. 브레인스토밍 또는 계획 단계를 완료했지만 아직 실제 코드를
   구현하지 않은 경우, DONE을 출력하지 마세요. 대신 구현으로 진행하거나
   사용자에게 진행 방법을 물어보세요.
7. **DONE 전 필수 납품물 확인**: DONE을 출력하기 전에, 세션 디렉토리에 모든
   필수 납품물이 존재하는지 확인하세요. 필수 파일이 누락된 경우, DONE을
   출력하기 전에 생성하세요. 각 하위 프로젝트는 스킬 문서에 자체 필수
   파일 목록을 정의합니다 (예: `dx-build-pipeline-app.md` 파일 생성 체크리스트).
8. **세션 HTML export 안내** (Copilot CLI 전용): DONE 센티넬 줄 바로 앞에
   다음을 출력하세요: `To save this session as HTML, type: /share html`
   — 이것은 사용자에게 전체 대화를 보존할 수 있음을 알려줍니다. `/share html`
   명령은 GitHub Copilot CLI에만 해당됩니다; Claude Code, Copilot Chat (VS Code),
   또는 OpenCode에서는 작동하지 않습니다. 테스트 하네스 (`test.sh`)가 자동으로
   내보낸 HTML 파일을 세션 출력 디렉토리에 복사합니다.

## 계획 출력 (필수)

계획 문서를 생성할 때 (예: writing-plans 또는 brainstorming 스킬을 통해),
파일 저장 직후 **항상 전체 계획 내용을 대화 출력에 인쇄하세요**. 파일 경로만
언급하지 마세요 — 사용자가 별도 파일을 열지 않고 프롬프트에서 직접 계획을
검토할 수 있어야 합니다.


---

## Instruction File Verification Loop (HARD GATE) — 내부 개발 전용

에이전트 지식 베이스 파일 수정 시 — 다음 패턴에 해당하는 파일:
`**/.cursor/**/*.mdc`, `**/.github/**/*.md`, `**/.opencode/**/*.md`,
`**/AGENTS*.md`, `**/CLAUDE*.md`, 또는 `**/.deepx/**/*.md` — 작업 완료를
선언하기 전에 다음 검증-수정 루프를 **반드시** 수행해야 합니다:

1. **자동화 테스트 루프** — `tests/test_agentic_scenarios/`를 실행하고 모든 실패를 수정:
   ```bash
   python -m pytest tests/test_agentic_scenarios/ -v --tb=short
   ```
2. **수동 감사** — 테스트 결과를 사용하지 않고, 실제 파일 내용을 읽어 크로스 플랫폼
   sync (CLAUDE vs AGENTS vs copilot)와 레벨 간 sync (suite → 하위 레벨)를 독립적으로
   검증합니다.
3. **갭 분석** — 수동 감사에서 테스트가 잡지 못한 이슈를 발견하면, **먼저 테스트
   케이스를 강화**한 후 파일을 수정합니다.
4. **반복** — 1단계로 돌아갑니다. 자동화 테스트 통과 AND 수동 감사 이슈 0건이
   될 때까지 계속 반복합니다.

**수동 감사가 필요한 이유**: 테스트는 알려진 패턴만 검증할 수 있습니다. 수동 감사는
상호 참조 방향 오류, 섹션 순서 문제, 의미론적 갭 등 기존 테스트가 커버하지 못하는
새로운 이슈를 발견합니다. 테스트 강화 후에도 수동 감사가 추가 이슈를 일관되게
발견해왔습니다.

이 게이트는 instruction 파일이 작업의 *주요 산출물*인 경우(예: 규칙 추가, 플랫폼 sync,
KO 번역 생성)에 적용됩니다. 기능 구현의 일부로 instruction 파일에 단순 한 줄 수정이
발생하는 경우에는 적용되지 않습니다.
