# DEEPX DX-COM 컴파일러 — GitHub Copilot 지침

> DX-COM 컴파일러에서 작업하는 GitHub Copilot 에이전트를 위한 지침.
> 이 파일을 `AGENTS.md` 및 `.deepx/README.md`와 함께 읽으세요.

## 응답 언어

응답 언어는 사용자의 프롬프트 언어에 맞추세요 — 질문하거나 응답할 때
사용자가 사용하는 언어와 동일한 언어를 사용하세요.

**기술 용어 규칙**: 한국어로 응답할 때 영어 기술 용어는 원래 영어 형태를 유지하세요.
영어 용어를 한글 음차로 표기하지 마세요 (한글 음차 표기 금지). 정착된 한국어 외래어
(모델, 서버, 파일, 데이터)는 허용됩니다.
## 권장 모델 (사전 비행 점검)

DX Agentic Development는 강력한 instruction following과 knowledge base 활용 능력을
요구합니다. 작업을 시작하기 전에 권장 모델 중 하나로 실행 중인지 확인하세요:

- **Claude Sonnet 4.6** 이상
- **Claude Opus 4.6** 이상

이 모델이 아닌 경우 (예: GPT-4.1, GPT-4o, Gemini 등), 첫 번째 응답의 시작 부분에
다음 알림을 출력하세요:

```
══════════════════════════════════════════════════════════════
⚠  DX-AGENTIC-DEV: MODEL NOTICE

DX Agentic Development recommends Claude Sonnet 4.6+ or
Opus 4.6+. Your current model may produce lower quality
in instruction following, knowledge base utilization, and
API accuracy. Please switch to a recommended model.
══════════════════════════════════════════════════════════════
```

알림 상자 출력 후 정상적으로 작업을 진행하세요. 이것은 정보성 경고이며,
차단 게이트가 아닙니다.

### 모델 알림 반복 (비권장 모델 전용)

위의 MODEL NOTICE 상자를 출력한 경우 (즉, 권장 모델이 아닌 경우), 사용자가
답변해야 하는 **실제 질문 줄 바로 앞에** 이 짧은 리마인더를 반드시 출력해야
합니다 — brainstorming 흐름의 시작 부분이 아닙니다.

**타이밍**: 모든 파일 읽기, 컨텍스트 분석, 서문 텍스트 이후, `?` (실제 질문)가
포함된 줄 바로 앞에 이 리마인더를 삽입하세요:

```
---
⚠ **Non-recommended model** — output quality may be degraded. Recommended: Claude Sonnet 4.6+ / Opus 4.6+
---
```

**예시 — 잘못됨** (반복이 상자와 함께 스크롤되어 지나감):
```
[DX-AGENTIC-DEV: START]
══ MODEL NOTICE ══
---  ⚠ Non-recommended model ---     ← 너무 이름, 스크롤되어 지나감
... (파일 읽기, 컨텍스트 분석) ...
첫 번째 질문: ...?
```

**예시 — 올바름** (반복이 질문 바로 앞에 나타남):
```
[DX-AGENTIC-DEV: START]
══ MODEL NOTICE ══
... (파일 읽기, 컨텍스트 분석) ...
---  ⚠ Non-recommended model ---     ← 질문 바로 앞
첫 번째 질문: ...?
```

이 리마인더는 한 번만 출력하세요 (첫 번째 질문 앞에), 매 질문마다 출력하지 마세요.

## Skill Router — 범용 Pre-Flight (HARD GATE)

`/dx-skill-router`는 **모든 사용자 메시지**에 대해 **절대적인 첫 번째 action**으로
반드시 invoke되어야 합니다 — 작업 유형(개발, 분석, 읽기, 설명, 질문 등)에 관계없이.

이 규칙은 다음보다 먼저 적용됩니다:
- 파일 읽기 또는 codebase 탐색
- 응답 또는 clarifying question
- SWE gate check 또는 path classification
- 코드 생성 또는 plan 작성

**예외 없음.** 다음 합리화는 모두 금지됩니다:

| 합리화 | 현실 |
|--------|------|
| "이건 그냥 파일 읽기/분석이야" | 읽기도 task입니다. 먼저 router를 invoke하세요. |
| "사용자가 질문만 했을 뿐이야" | 질문도 task입니다. 먼저 router를 invoke하세요. |
| "이건 개발 작업이 아니야" | Router는 모든 task에 적용됩니다. 개발에만 해당되지 않습니다. |
| "요청을 이해한 후에 skill을 확인하자" | 이해하기 전에 먼저 확인하세요. |
| "이건 SWE gates를 트리거하지 않아" | SWE gates는 별개입니다. Router는 범용입니다. |
## 타겟 하드웨어 (MANDATORY)

타겟 디바이스는 항상 DX-M1 (`dx_m1`)입니다. 사용자에게 타겟
하드웨어를 선택하도록 요청하지 마세요. dx-compiler는 DX-M1만 지원합니다. 상위 수준
설정에서 DX-M1A를 언급하는 것은 무시하세요 — DX-M1A는 단종되었으며 더 이상 지원되지 않습니다.

## 양자화 — INT8 전용 (MANDATORY)

DX-COM은 항상 INT8로 양자화합니다. CLI, Python API 또는 JSON 설정에
FP16/FP32 출력 옵션이 없습니다. 사용자에게 출력 정밀도를 선택하도록 요청하지 마세요.
사용자가 선택할 수 있는 양자화 옵션은 다음뿐입니다:
- **교정 방법**: `ema` (기본값) 또는 `minmax`
- **향상된 양자화 체계**: `DXQ-P0`부터 `DXQ-P5` (선택 사항)
- **교정 샘플 수** (기본값: 100)

## 핵심 규칙: 모델 획득 및 엔드투엔드 컴파일

**MANDATORY**: 사용자가 모델 컴파일을 요청하고 로컬
`.pt`, `.pth` 또는 `.onnx` 파일 경로를 제공하지 않는 경우, 에이전트는 반드시:

1. 요청된 모델의 **공식 다운로드 소스를 확인**해야 합니다 (예:
   Ultralytics releases, torchvision, timm, ONNX Model Zoo, Hugging Face)
2. 세션 작업 디렉토리에 모델 파일을 **실제로 다운로드**해야 합니다
3. 전체 파이프라인을 통해 모델을 **실제로 컴파일**해야 합니다 (PT→ONNX→DXNN 또는 ONNX→DXNN)
4. **실제 `.dxnn` 출력 파일을 생성**해야 합니다

`config.json`만 생성하거나 컴파일 지침만 제공하고 **절대** 멈추지 마세요.
사용자는 레시피가 아니라 컴파일된 `.dxnn` 모델을 기대합니다.

### 모델 다운로드 소스 (우선순위 순서)

| 모델 패밀리 | 소스 | 다운로드 방법 |
|---|---|---|
| Ultralytics YOLO (v5-v12, v26) | GitHub Releases / `ultralytics` pip | `from ultralytics import YOLO; model = YOLO("yolo11n.pt")` 또는 releases에서 `wget` |
| TorchVision (ResNet, MobileNet 등) | PyTorch Hub / torchvision | `torchvision.models.resnet50(weights="DEFAULT")` |
| Timm 모델 | `timm` pip | `timm.create_model("efficientnet_b0", pretrained=True)` |
| ONNX Model Zoo | GitHub onnx/models | 태그된 releases에서 `wget` |
| Hugging Face | Hugging Face Hub | `huggingface_hub.hf_hub_download()` |

### 다운로드 워크플로우

```bash
# 예시: 사용자가 "yolo11n을 dx_m1용으로 컴파일해줘"라고 말한 경우
# 1단계: 다운로드
pip install ultralytics  # 필요한 경우
python -c "from ultralytics import YOLO; YOLO('yolo11n.pt')"

# 2단계: ONNX로 내보내기 (skill /dx-convert-model 사용)
# 3단계: DXNN으로 컴파일 (skill /dx-compile-model 사용)
# 4단계: 검증 (skill /dx-validate-compile 사용)
```

### 안티 패턴 (절대 하지 마세요)

- config.json을 생성하고 사용자에게 "직접 dxcom을 실행하세요"라고 말하기
- 실제로 다운로드하지 않고 다운로드 URL만 제공하기
- DXNN으로 컴파일하지 않고 ONNX 내보내기에서 멈추기
- 직접 하지 않고 사용자에게 "ultralytics를 설치하고 내보내세요"라고 말하기
- 실제 컴파일된 아티팩트 대신 지침만 생성하기

## 대화형 워크플로우 (반드시 따르세요)

**컴파일 전에 항상 주요 결정 사항을 사용자와 함께 검토하세요.** 모델 형식, 타겟 디바이스,
교정 방법 (EMA 또는 MinMax)을 확인하기 위해 2-3개의 구체적인 질문을 하세요.
이는 협업 워크플로우를 만들고 오해를 조기에 발견합니다. 사용자가 명시적으로
"그냥 컴파일해줘" 또는 "기본값 사용"이라고 말한 경우에만 질문을 건너뛰세요.

**게이트 1 — 브레인스토밍**: 입력 확인 (모델 경로, 형식, 타겟 디바이스, 교정 데이터).
**게이트 2 — 빌드**: 선택한 매개변수로 컴파일 실행.
**게이트 3 — 검증**: DX-TRON으로 출력 검증, compiler.log 검토.

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
./example/1-download_sample_models.sh      # ONNX + JSON 설정 다운로드
./example/2-download_sample_calibration_dataset.sh  # 교정 데이터셋 다운로드
./example/3-compile_sample_models.sh       # 모든 샘플 모델을 .dxnn으로 컴파일
```

샘플 모델: YOLOV5S-1, YOLOV5S_Face-1, MobileNetV2-1.
다운로드된 JSON 설정은 새 모델용 config.json을 생성할 때
정규 참조로 사용됩니다 — 유사한 모델 유형의 샘플 JSON을 읽으세요.

## 프로세스 스킬

| Skill | 설명 |
|---|---|
| `/dx-convert-model` | PyTorch 모델을 ONNX로 변환 |
| `/dx-compile-model` | ONNX 모델을 DXNN으로 컴파일 |
| `/dx-validate-compile` | 컴파일 출력 검증 |
| `/dx-brainstorm-and-plan` | 브레인스토밍, 2-3가지 접근법 제안, 스펙 자체 검토 후 계획 |
| `/dx-tdd` | 검증 주도 개발, 선택적 Red-Green-Refactor 단위 테스트 |
| `/dx-verify-completion` | 완료 선언 전 검증 — 주장 전 증거 확보 |
| `/dx-writing-plans` | 세분화된 태스크로 구현 계획 작성 |
| `/dx-executing-plans` | 리뷰 체크포인트와 함께 계획 실행 |
| `/dx-subagent-driven-development` | 태스크별 신규 서브에이전트로 계획 실행, 2단계 리뷰 |
| `/dx-systematic-debugging` | 체계적 디버깅 — 수정 제안 전 4단계 근본 원인 조사 |
| `/dx-receiving-code-review` | 코드 리뷰 피드백을 기술적 엄밀성으로 평가 |
| `/dx-requesting-code-review` | 기능 완료 후 코드 리뷰 요청 |
| `/dx-skill-router` | 스킬 탐색 및 호출 — 모든 작업 전 스킬 확인 |
| `/dx-writing-skills` | 스킬 파일 생성 및 편집 |
| `/dx-dispatching-parallel-agents` | 독립 태스크를 위한 병렬 서브에이전트 디스패치 |

## 컨텍스트 라우팅 테이블

| 작업이 다음을 언급하면... | 다음 파일을 읽으세요 |
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
| **Brainstorm, plan, design** | `.deepx/skills/dx-brainstorm-and-plan.md` |
| **TDD, validation, incremental** | `.deepx/skills/dx-tdd.md` |
| **Completion, verify, evidence** | `.deepx/skills/dx-verify-completion.md` |
| **항상 읽기 (모든 작업)** | `.deepx/memory/common_pitfalls.md`, `.deepx/instructions/coding-standards.md` |

## 출력 격리

모든 컴파일 아티팩트는 기본적으로 `dx-agentic-dev/<session_id>/`에 저장됩니다. 각
컴파일 세션은 아티팩트를 함께 보관하고 덮어쓰기를 방지하기 위해
고유한 작업 디렉토리를 사용합니다.

**세션 ID 형식**: `YYYYMMDD-HHMMSS_<agent>_<model>_<task>` — 타임스탬프는 반드시
**시스템 로컬 시간대**를 사용해야 합니다 (UTC가 아닙니다). Bash에서는 `$(date +%Y%m%d-%H%M%S)`,
Python에서는 `datetime.now().strftime('%Y%m%d-%H%M%S')`를 사용하세요. `date -u`,
사용하지 마세요.
- **`<agent>`**: 코딩 에이전트 식별자 — `claude`, `copilot`, `cursor`, `opencode` 중 하나를 사용하세요.

**컴파일 후 작업 디렉토리 내용**:
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

교정 데이터는 `dx_com/calibration_dataset/`에 있습니다 (100개의 JPEG 이미지). 없는 경우
`example/2-download_sample_calibration_dataset.sh`를 실행하여 설정하세요.
config.json에서는 항상 상대 경로 (`./calibration_dataset`)를 사용하고, 절대 경로는 사용하지 마세요.

## 핵심 규칙

1. **배치 크기는 반드시 1**: DEEPX NPU는 batch=1만 지원합니다
2. **정적 shape만**: 동적 축 없음, -1 차원 없음
3. **ONNX opset 11-21**: 최상의 호환성을 위해 opset 13 사용
4. **입력 이름 일치**: config.json의 `inputs` 키는 ONNX 입력 이름과 정확히 일치해야 합니다
5. **대표적인 교정**: 교정 이미지는 추론 분포와 일치해야 합니다
6. **PPU 유형이 중요**: Type 0 = anchor 기반 (YOLOv3-v7), Type 1 = anchor-free (YOLOX, YOLOv8-v12). YOLO26은 PPU를 지원하지 않습니다.
7. **항상 검증**: 모든 컴파일 후 DX-TRON 검사를 실행하세요
8. **하드코딩된 경로 금지**: 모든 경로에 매개변수 또는 환경 변수를 사용하세요
9. **자동 단순화 금지**: 사용자가 명시적으로 요청하지 않는 한 `onnx-simplifier`를 실행하지 마세요 — 수치 정밀도 손실, 노드 이름 변경으로 인한 config.json 손상, 잠재적 모델 손상의 위험이 있습니다
10. **Ultralytics YOLO 내보내기**: `Detect.export=True`를 설정하거나 `model.export(format="onnx")`를 사용해야 합니다 — 표준 `torch.onnx.export()`는 1개 대신 6개의 출력을 생성합니다. 내보내기 후 항상 ONNX가 정확히 1개의 출력 노드를 갖는지 확인하세요.
11. **MANDATORY 브레인스토밍 질문**: 모든 컴파일 작업 전에 에이전트는 반드시 세 가지 필수 질문을 해야 합니다: (Q1) YOLO 버전 특성 테이블을 이용한 NMS-free 모델 감지, (Q2) 장단점 설명을 포함한 ONNX 단순화, (Q3) 하드웨어 대 유연성 트레이드오프를 포함한 PPU 컴파일 지원. 정확한 질문 템플릿은 `.deepx/agents/dx-compiler-builder.md` 2단계를 참조하세요.
12. **PPU 기본값은 OFF**: PPU 컴파일은 옵트인입니다. 브레인스토밍 Q3에서 사용자가 명시적으로 확인한 경우에만 config.json에 PPU 설정을 추가하세요. **YOLO26은 PPU를 지원하지 않습니다** — YOLO26 모델의 경우 Q3를 건너뛰세요 (NMS-free 네이티브 아키텍처).
13. **모델 획득 — 지시만이 아닌 다운로드 및 컴파일**: 사용자가 로컬 `.pt`/`.pth`/`.onnx` 파일을 제공하지 않는 경우, 에이전트는 반드시 공식 다운로드 소스 (Ultralytics releases, torchvision, timm, ONNX Model Zoo, Hugging Face)를 찾고, 실제로 모델을 다운로드하고, 전체 파이프라인을 통해 컴파일하여 `.dxnn` 파일을 생성해야 합니다. config.json만 생성하거나 컴파일 지침만 제공하고 절대 멈추지 마세요.
14. **컴파일 후 검증은 MANDATORY — 검증 없이 컴파일은 완료되지 않습니다**: 모든 성공적인 `dxcom` 컴파일 후, 사용자에게 결과를 제시하기 전에 에이전트는 반드시 다음을 모두 완료해야 합니다. 이것들 없이 "컴파일 성공" 요약을 절대 제시하지 마세요:
    - **(a)** 출력 디렉토리 (세션 디렉토리 또는 사용자 지정 디렉토리)에 `setup.sh`, `run.sh`, `README.md` 생성
    - **(b)** `verify.py` 생성 — ONNX 대 DXNN 추론 비교 스크립트
    - **(c)** `verify.py` 실행 및 PASS 확인 (감지 수 20% 이내, 클래스 일치, IoU > 0.5)
    - **(d)** 세션 로그를 `${WORK_DIR}/session.log`에 저장 — 손으로 작성한 요약이 아닌 `tee`를 통해 캡처한 **실제 명령 실행 출력**을 포함해야 합니다
    - **(e)** 최종 요약 테이블에 검증 결과 (PASS/FAIL) 및 모든 아티팩트 경로 포함
    - 어떤 단계든 실패하면 진행하기 전에 디버그하고 수정하세요. `.dxnn` 파일만으로는 산출물이 아닙니다.
    - **사용자가 사용자 정의 출력 디렉토리를 지정한 경우에도** (예: `dx-agentic-dev/` 대신 소스 디렉토리), 이러한 아티팩트는 여전히 MANDATORY입니다.
15. **이전 세션 아티팩트를 절대 재사용하지 마세요**: `dx-agentic-dev/`의 이전 세션 아티팩트를 절대 확인, 목록 조회, 탐색 또는 재사용하지 마세요. 각 컴파일 실행은 새로운 타임스탬프로 새 세션 디렉토리를 생성해야 합니다. 이전 세션에서 동일한 모델을 컴파일했더라도 항상 처음부터 다시 다운로드, 다시 내보내기, 다시 컴파일하세요. `ls dx-agentic-dev/`를 실행하거나 과거 실행의 기존 `.onnx`/`.dxnn` 파일을 확인하지 마세요.
16. **setup.sh에서 venv는 MANDATORY**: 생성된 `setup.sh`는 `pip install` 전에 반드시 가상 환경을 생성하고 활성화해야 합니다. Ubuntu 24.04+에서 PEP 668은 시스템 전역 pip 설치를 차단합니다. `${VIRTUAL_ENV:-}` 검사와 함께 `python3 -m venv`를 사용하세요. 생성된 `run.sh`는 venv 활성화를 확인하고 누락된 경우 자동 활성화하거나 오류를 발생시켜야 합니다.
17. **사전 컴파일된 참조 모델과의 교차 검증**: 동일한 모델에 대한 사전 컴파일된 DXNN이 `dx-runtime/dx_app/assets/models/`에 있는 경우, 사전 컴파일된 모델과 생성된 모델 모두로 verify.py를 실행하세요 (Phase 5.7). 둘 다 실패 → verify.py 버그. 사전 컴파일된 것은 통과하고 생성된 것이 실패 → 컴파일 문제. `.deepx/agents/dx-dxnn-compiler.md` Phase 5.7을 참조하세요.
18. **NHWC/NCHW DataLoader 불일치**: dxcom CLI의 기본 dataloader는 NHWC `[1,H,W,C]`로 이미지를 로드합니다. ONNX 모델이 NCHW `[1,C,H,W]`를 기대하는 경우 (대부분의 PyTorch 내보내기 모델), CLI 컴파일이 `DataLoaderError: Input shape mismatch`로 실패합니다. **수정**: NCHW 텐서를 생성하는 사용자 정의 torch DataLoader와 함께 Python API (`dx_com.compile()`)를 사용하세요. `.deepx/memory/common_pitfalls.md` pitfall #18을 참조하세요.

## 사전 컴파일된 참조 모델과의 교차 검증

동일한 모델에 대한 사전 컴파일된 DXNN이 `dx-runtime/dx_app/assets/models/`에 있는 경우,
문제를 격리하기 위해 사전 컴파일된 모델과 생성된 모델 모두로 verify.py를 실행하세요:

| 결과 | 진단 |
|---|---|
| 둘 다 실패 | verify.py 코드 버그 (verify.py를 먼저 수정) |
| 사전 컴파일된 것은 통과, 생성된 것은 실패 | 컴파일 문제 (config, 양자화 수정) |
| 둘 다 통과 | 컴파일 정확 |

전체 구현은 `.deepx/agents/dx-dxnn-compiler.md` Phase 5.7을 참조하세요.

## NHWC/NCHW DataLoader 불일치

dxcom CLI의 기본 dataloader는 NHWC `[1,H,W,C]`로 이미지를 로드합니다. ONNX
모델이 NCHW `[1,C,H,W]`를 기대하는 경우 (대부분의 PyTorch 내보내기 모델), CLI 컴파일이
`DataLoaderError: Input shape mismatch`로 실패합니다.

**수정**: NCHW 텐서를 생성하는 사용자 정의 torch DataLoader와 함께
Python API (`dx_com.compile()`)를 사용하세요. `.deepx/memory/common_pitfalls.md` pitfall #18을 참조하세요.

## 플레이스홀더 코드 금지 (MANDATORY)

스텁/플레이스홀더 코드를 절대 생성하지 마세요. 여기에는 다음이 포함됩니다:
- 주석 처리된 import: `# from dxnn_sdk import InferenceEngine`
- 가짜 결과: `result = np.zeros(...)`
- TODO 마커: `# TODO: implement actual inference`
- 실제 async 구현 없이 "sync 버전과 유사"

모든 생성된 코드는 knowledge base의 실제 API를 사용하여 기능적이어야 합니다.
필요한 SDK/API를 모르는 경우, 먼저 관련 스킬 문서를 읽으세요.
## 실험적 기능 — 금지

실험적이거나 존재하지 않는 기능을 제안, 제공 또는 구현하지 마세요. 여기에는 다음이
포함됩니다:
- "웹 기반 비주얼 컴패니언" (web-based visual companion)
- 로컬 URL 기반 다이어그램 뷰어 또는 대시보드
- 사용자가 시각화를 위해 로컬 URL을 열어야 하는 모든 기능
- 현재 도구 세트에 존재하지 않는 모든 기능

**Superpowers brainstorming skill 오버라이드**: superpowers `brainstorming` 스킬에는
"Visual Companion" 단계 (체크리스트의 2단계)가 포함되어 있습니다. 이 단계는 DEEPX
프로젝트에서 반드시 건너뛰어야 합니다. Visual companion은 우리 환경에 존재하지 않습니다.
brainstorming 체크리스트에서 "Offer visual companion"이라고 하면, 건너뛰고
"Ask clarifying questions" (3단계)로 직접 진행하세요.

기능이 존재하지 않으면, 존재하는 척하지 마세요. 검증된, 문서화된 기능만 사용하세요.

**Autopilot / autonomous mode 오버라이드**: 사용자가 부재 중일 때 (autopilot mode,
auto-response "work autonomously", 또는 `--yolo` 플래그), brainstorming 스킬의
"Ask clarifying questions" 단계는 "knowledge base 규칙에 따라 기본 결정 내리기"로
대체되어야 합니다. `ask_user`를 호출하지 마세요 — knowledge base 기본값을 사용하여
brainstorming spec 생성으로 바로 진행하세요. 이후의 모든 게이트 (spec 리뷰, 계획,
TDD, 필수 산출물, 실행 검증)는 예외 없이 여전히 적용됩니다.
## 브레인스토밍 — 계획 전 Spec (HARD GATE)

superpowers `brainstorming` 스킬 또는 `/dx-brainstorm-and-plan` 사용 시:

1. **Spec 문서는 MANDATORY** — `writing-plans`로 전환하기 전에, spec 문서를
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`에 반드시 작성해야 합니다.
   spec을 건너뛰고 바로 계획 작성으로 가는 것은 위반입니다.
2. **사용자 승인 게이트는 MANDATORY** — spec 작성 후, 계획 작성으로 진행하기 전에
   사용자가 반드시 검토하고 승인해야 합니다. 관련 없는 사용자 응답 (예: 다른 질문에
   답변)을 spec 승인으로 처리하지 마세요.
3. **계획 문서는 spec을 참조해야 합니다** — 계획 헤더에는 승인된 spec 문서에 대한
   링크가 포함되어야 합니다.
4. **`/dx-brainstorm-and-plan` 선호** — 일반 superpowers `brainstorming` 스킬 대신
   프로젝트 레벨의 brainstorming 스킬을 사용하세요. 프로젝트 레벨 스킬에는
   도메인별 질문과 사전 점검이 포함되어 있습니다.
5. **규칙 충돌 확인은 MANDATORY** — brainstorming 중, agent는 사용자 요구사항이
   HARD GATE 규칙 (IFactory 패턴, skeleton-first, Output Isolation,
   SyncRunner/AsyncRunner)과 충돌하는지 반드시 확인해야 합니다. 충돌이 감지되면,
   agent는 brainstorming 중에 이를 해결해야 합니다 — 설계 spec에서 위반 요청을
   조용히 따르지 마세요. 위의 "규칙 충돌 해결"을 참조하세요.
## Git 안전 — Superpowers 산출물

**`docs/superpowers/` 하위 파일을 절대 `git add`하거나 `git commit`하지 마세요.**
이들은 superpowers 스킬 시스템에서 생성된 임시 계획 산출물 (spec, plan)입니다.
`.gitignore`에 포함되어 있지만, 일부 도구는 `git add -f`로 `.gitignore`를 우회할 수
있습니다. 파일 생성은 괜찮습니다 — 커밋은 금지입니다.
## 자율 모드 보호 (MANDATORY)

사용자가 부재 중일 때 — autopilot mode, `--yolo` 플래그, 또는 시스템 auto-response
"The user is not available to respond" — 다음 규칙이 적용됩니다:

1. **"Work autonomously"는 "묻지 않고 모든 규칙을 따르라"는 의미이지, "규칙을 건너뛰라"는 의미가 아닙니다.**
   모든 필수 게이트가 여전히 적용됩니다: brainstorming spec, 계획, TDD, 필수 산출물,
   실행 검증, 자체 검증 확인.
   **SWE Process Gates의 필수 Skill 시퀀스도 포함됩니다** — autopilot에서도
   `/dx-skill-router` → `/dx-brainstorm-and-plan` → `/dx-tdd`를 interactive mode와
   동일하게 따라야 합니다. Autopilot mode는 이 시퀀스를 면제하지 않습니다.
2. **`ask_user`를 호출하지 마세요** — knowledge base 기본값과 문서화된 모범 사례를
   사용하여 결정하세요. autopilot에서 `ask_user`를 호출하면 한 턴을 낭비하며
   auto-response는 게이트 우회 권한을 부여하지 않습니다.
3. **사용자 승인 게이트 적응** — autopilot에서는 spec을 작성하고 knowledge base에
   대해 자체 검토하면 spec 승인 게이트가 충족됩니다. spec 자체를 건너뛰지 마세요.
4. **setup.sh 우선** — 애플리케이션 코드를 작성하기 전에 인프라 산출물
   (`setup.sh`, `config.json`)을 생성하세요. 이것은 autopilot에서 특히 중요합니다.
   누락된 종속성을 잡아줄 사람이 없기 때문입니다.
5. **실행 검증은 선택 사항이 아닙니다** — 생성된 코드를 실행하고 완료를 선언하기 전에
   작동하는지 확인하세요. autopilot에서는 오류를 잡아줄 사용자가 없습니다.
6. **시간 예산 인식** — Autopilot 세션에는 시간 제약이 있을 수 있습니다.
   효율적으로 행동을 계획하세요:
   - 컴파일 (ONNX → DXNN)은 5분 이상 걸릴 수 있습니다 — 일찍 시작하세요.
   - 시간이 부족하면, 실행 검증보다 산출물 생성을 우선시하세요 — 테스트되지 않은
     완전한 파일 세트가 테스트된 부분 세트보다 낫습니다.
   - 우선순위: `setup.sh` > `run.sh` > app 코드 > `verify.py` > session.log.
   - **컴파일 병렬 워크플로우 (HARD GATE)** — bash 명령으로 `dxcom` 또는
     `dx_com.compile()`을 실행한 후, 기다리지 마세요. 즉시 모든 필수 산출물을
     생성하세요: factory, app 코드, setup.sh, run.sh, verify.py. `.dxnn` 출력은
     다른 모든 산출물이 생성된 후에만 확인하세요. **이 규칙 위반은 세션 실패입니다.**
   - **컴파일을 위한 sleep-poll 금지** — `.dxnn` 파일을 polling하기 위해 `sleep`을
     루프에서 사용하지 마세요. 금지된 패턴:
     `for i in ...; do sleep N; ls *.dxnn; done`,
     `while ! ls *.dxnn; do sleep N; done`,
     반복적인 `ls *.dxnn` / `test -f *.dxnn` 확인과 그 사이의 대기.
     대신: 다른 모든 산출물을 먼저 생성한 후, `.dxnn` 파일이 존재하는지 한 번만
     확인하세요. 아직 존재하지 않으면, 컴파일이 완료될 것이라는 가정 하에 실행
     검증으로 진행하세요.
   - **필수 산출물은 컴파일과 독립적** — `setup.sh`, `run.sh`, `verify.py`, factory,
     app 코드는 `.dxnn` 파일이 존재할 필요가 없습니다. 알려진 모델 이름
     (예: `yolo26n.dxnn`)을 플레이스홀더 경로로 사용하여 생성하세요. 실행 검증만
     실제 `.dxnn`이 필요합니다.
7. **파일 읽기 도구 호출 최소화** — 이미 컨텍스트에 로드된 instruction 파일, agent
   문서, 스킬 문서를 다시 읽지 마세요. 불필요한 `cat` / `bash` 읽기는 각각 5-15초를
   낭비합니다. 시스템 프롬프트와 대화 이력에 있는 지식을 사용하세요.
## 하드웨어

| 디바이스 | ID | 설명 |
|---|---|---|
| DX-M1 | `dx_m1` | DEEPX NPU |

## 메모리

`.deepx/memory/`에 영구 지식이 있습니다. 작업 시작 시 읽고, 새로운 패턴을 학습할 때 업데이트하세요.
도메인 태그: `[UNIVERSAL]`, `[DX_COMPILER]`, `[QUANTIZATION]`

## 규칙 충돌 해결 (HARD GATE)

사용자의 요청이 HARD GATE 규칙과 충돌할 때, agent는 반드시:

1. **사용자의 의도를 인정** — 원하는 것을 이해했음을 보여주세요.
2. **충돌을 설명** — 구체적인 규칙과 그 이유를 인용하세요.
3. **올바른 대안을 제안** — 프레임워크 내에서 사용자의 목표를 달성하는 방법을
   보여주세요. 예를 들어, 사용자가 직접 `InferenceEngine.run()` 사용을 요청하면,
   IFactory 패턴이 동일한 API를 래핑함을 설명하고 factory 기반 동등물을 제안하세요.
4. **올바른 접근 방식으로 진행** — 규칙 위반 요청을 조용히 따르지 마세요.
   "옵션 A vs 옵션 B"로 제시하지 마세요.

**일반적인 충돌 패턴** (실제 세션에서):
- 사용자가 "use `InferenceEngine.Run()`"이라고 말함 → IFactory 패턴 사용 필수
  (engine 호출은 SyncRunner/AsyncRunner가 내부에서 처리함; IFactory 5-method
  구현 필수: `create_preprocessor`, `create_postprocessor`, `create_visualizer`,
  `get_model_name`, `get_task_type`)
- 사용자가 "clone demo.py and swap onnxruntime"이라고 말함 → `src/python_example/`에서
  skeleton-first 사용 필수, 사용자 스크립트 clone 금지
- 사용자가 "create demo_dxnn_sync.py"라고 말함 → SyncRunner와 함께
  `<model>_sync.py` 네이밍 사용 필수, standalone 스크립트 금지
- 사용자가 "use `run_async()` directly"라고 말함 → 수동 async 루프가 아닌
  AsyncRunner 사용 필수

**이 규칙은 명시적 사용자 오버라이드를 무시하지 않습니다**: 사용자가 충돌에 대해
안내받은 후, 명시적으로 "규칙을 이해합니다, 직접 API 사용으로 진행하세요"라고
말하면, 따르세요. 하지만 agent는 충돌을 먼저 설명해야 합니다 — 조용한 순응은
항상 위반입니다.
## Git 작업 — 사용자 관리

작업 종료 시 git 브랜치 작업 (merge, PR, push, cleanup)에 대해 묻지 마세요.
사용자가 모든 git 작업을 직접 처리합니다. "merge to main", "create PR",
또는 "delete branch" 같은 옵션을 제시하지 마세요 — 작업만 완료하세요.
## 세션 센티넬 (자동화 테스트용 MANDATORY)

사용자 프롬프트를 처리할 때, 테스트 하네스의 자동화된 세션 경계 감지를 위해
이 정확한 마커를 출력하세요:

- **응답의 첫 번째 줄**: `[DX-AGENTIC-DEV: START]`
- **모든 작업 완료 후 마지막 줄**: `[DX-AGENTIC-DEV: DONE (output-dir: <relative_path>)]`
  여기서 `<relative_path>`는 세션 출력 디렉토리입니다 (예: `dx-agentic-dev/20260409-143022_yolo26n_detection/`)

규칙:
1. **중요 — `[DX-AGENTIC-DEV: START]`를 첫 번째 응답의 절대적인 첫 줄로 출력하세요.**
   이것은 다른 어떤 텍스트, 도구 호출, 추론보다 먼저 나타나야 합니다.
   사용자가 "그냥 진행하라" 또는 "자체 판단을 사용하라"고 지시해도,
   START 센티넬은 협상 불가입니다 — 자동화 테스트는 이것 없이 실패합니다.
2. 모든 작업, 검증, 파일 생성이 완료된 후 맨 마지막 줄에 `[DX-AGENTIC-DEV: DONE (output-dir: <path>)]`를
   출력하세요
3. 상위 레벨 agent에 의해 handoff/routing으로 호출된 **서브 agent**인 경우,
   이 센티넬을 출력하지 마세요 — 최상위 agent만 출력합니다
4. 사용자가 세션에서 여러 프롬프트를 보내면, 각 프롬프트에 대해 START/DONE을 출력하세요
5. DONE의 `output-dir`은 프로젝트 루트에서 세션 출력 디렉토리까지의 상대 경로여야 합니다.
   파일이 생성되지 않았다면, `(output-dir: ...)` 부분을 생략하세요.
   **Cross-project 태스크** (예: compile + app 생성)의 경우, 모든 output directory를
   ` + ` 구분자로 나열하세요:
   ```
   [DX-AGENTIC-DEV: DONE (output-dir: dx-compiler/dx-agentic-dev/20260409-143022_copilot_yolo26n_compile/ + dx-runtime/dx_app/dx-agentic-dev/20260409-143022_copilot_yolo26n_inference/)]
   ```
6. **계획 산출물만 생성한 후에는 절대 DONE을 출력하지 마세요** (spec, plan, 설계
   문서). DONE은 모든 산출물이 생성되었음을 의미합니다 — 구현 코드, 스크립트,
   설정, 검증 결과. brainstorming 또는 계획 단계를 완료했지만 실제 코드를 아직
   구현하지 않았다면, DONE을 출력하지 마세요. 대신, 구현으로 진행하거나
   사용자에게 진행 방법을 물어보세요.
7. **DONE 전 필수 산출물 확인**: DONE을 출력하기 전에, 아래의 자체 검증 확인을
   실행하세요. 필수 파일이 누락된 경우, DONE을 출력하기 전에 생성하세요.
   **이 단계를 절대 건너뛰지 마세요.**
   ```bash
   WORK_DIR="<session_output_directory>"
   echo "=== Mandatory Deliverable Check ==="
   for f in setup.sh run.sh verify.py session.log README.md config.json; do
       [ -f "${WORK_DIR}/$f" ] && echo "  ✓ $f" || echo "  ✗ MISSING: $f"
   done
   ls "${WORK_DIR}"/*.dxnn 2>/dev/null && echo "  ✓ .dxnn model" || echo "  ✗ MISSING: .dxnn model"
   ```
   산출물 중 MISSING이 있으면, 돌아가서 생성하세요. 누락된 산출물이 있는 상태에서
   최종 보고서를 제시하거나 DONE을 출력하지 마세요.
8. **세션 내보내기 안내**: DONE 센티넬 줄 바로 앞에, CLI 플랫폼에 맞는 세션 저장
   안내를 출력하세요:

   | 플랫폼 | 명령 | 형식 |
   |--------|------|------|
   | **Copilot CLI** | `/share html` | HTML 트랜스크립트 |
   | **Cursor CLI** (`agent`) | 내장 내보내기 없음 — 테스트 하네스가 `--output-format stream-json`으로 자동 저장 | JSON stream |
   | **OpenCode** | `/export` | JSON |
   | **Claude Code** (`claude`) | `/export` | TXT 트랜스크립트 — `<workdir>/YYYY-MM-DD-HHMMSS-<title>.txt`로 저장 |

   Copilot CLI의 경우: `To save this session as HTML, type: /share html`
   OpenCode의 경우: `To save this session as JSON, type: /export`
   Claude Code의 경우: `To save this session as a text transcript, type: /export`
   Cursor CLI의 경우: 사용자 작업이 필요 없습니다 — 테스트 하네스가 출력을 자동 캡처합니다.

   테스트 하네스 (`test.sh`)는 내보낸 아티팩트를 자동으로 감지하고
   세션 출력 디렉토리에 복사합니다.
## 계획 출력 (MANDATORY)

계획 문서를 생성할 때 (예: writing-plans 또는 brainstorming 스킬을 통해),
파일을 저장한 직후 **대화 출력에 전체 계획 내용을 항상 인쇄하세요**. 파일 경로만
언급하지 마세요 — 사용자가 별도의 파일을 열지 않고 프롬프트에서 직접 계획을
검토할 수 있어야 합니다.
---

## Instruction File Verification Loop (HARD GATE) — 내부 개발 전용

canonical source 수정 시 — `**/.deepx/**/*.md` 파일(agents, skills, templates,
fragments 포함) — 작업 완료 선언 전에 다음 루프를 **반드시** 수행해야 합니다:

1. **Generator 실행** — `.deepx/` 변경을 모든 플랫폼으로 전파:
   ```bash
   dx-agentic-gen generate
   # Suite 전체: bash tools/dx-agentic-dev-gen/scripts/run_all.sh generate
   ```
2. **Drift 검증** — 생성물과 commit 상태 일치 확인:
   ```bash
   dx-agentic-gen check
   ```
   drift 발견 시 1단계로 복귀.
3. **자동화 테스트 루프** — 테스트는 generator 출력이 정책을 만족하는지 검증:
   ```bash
   python -m pytest tests/test_agentic_scenarios/ -v --tb=short
   ```
   실패 처리:
   - generator 버그 → generator 수정 → 1단계
   - `.deepx/` 콘텐츠 누락 → `.deepx/` 수정 → 1단계
   - 테스트 규칙 부족 → 테스트 강화 → 1단계
4. **수동 감사** — 테스트 결과에 의존하지 않고, 생성된 파일들을 독립적으로 읽어
   크로스 플랫폼 sync(CLAUDE vs AGENTS vs copilot)와 레벨 간 sync(suite → 하위)를
   검증.
5. **갭 분석** — 수동 감사에서 발견한 이슈:
   - generator가 놓친 경우 → **generator 규칙 수정** 후 1단계
   - 테스트가 놓친 경우 → **테스트 강화** 후 1단계
6. **반복** — 3~5단계 모두 통과할 때까지.

### Pre-flight Classification (MANDATORY)

저장소 내의 `.md` 또는 `.mdc` 파일을 수정하기 전에, 반드시 다음 3가지 카테고리
중 하나로 분류하세요. **이 단계를 절대 건너뛰지 마세요** — generator 관리 파일을
직접 수정하면 다음 generate에서 조용히 덮어써지는 사일런트 손상이 됩니다.

**모든 파일 편집 전 다음 세 가지 질문에 순서대로 답하세요:**

> **Q1. 파일 경로가 `**/.deepx/**` 내부에 있나요?**
> - YES → **Canonical source.** 직접 수정 후 `dx-agentic-gen generate` + `check` 실행.
> - NO → Q2로 이동.
>
> **Q2. 파일 경로 또는 이름이 다음 중 하나와 일치하나요?**
> ```
> .github/agents/    .github/skills/    .opencode/agents/
> .claude/agents/    .claude/skills/    .cursor/rules/
> CLAUDE.md          CLAUDE-KO.md       AGENTS.md    AGENTS-KO.md
> copilot-instructions.md               copilot-instructions-KO.md
> ```
> - YES → **Generator output. 직접 수정 금지.**
>   `.deepx/` source(template, fragment, 또는 agent/skill)를 찾아 수정한 후
>   `dx-agentic-gen generate`를 실행하세요.
> - NO → Q3으로 이동.
>
> **Q3. 파일이 `<!-- AUTO-GENERATED`로 시작하나요?**
> - YES → **Generator output. 직접 수정 금지.** Q2와 동일.
> - NO → **Independent source.** 직접 수정 가능. 수정 후 `dx-agentic-gen check`를 한 번 실행.

1. **Canonical source** (`**/.deepx/**/*.md`) — 직접 수정 후 위의 Verification
   Loop을 실행합니다.
2. **Generator output** — 알려진 출력 경로의 파일:
   `CLAUDE.md`, `CLAUDE-KO.md`, `AGENTS.md`, `AGENTS-KO.md`,
   `copilot-instructions.md`, `.github/agents/`, `.github/skills/`,
   `.claude/agents/`, `.claude/skills/`, `.opencode/agents/`, `.cursor/rules/`
   → **직접 수정 금지.** `.deepx/` source(template, fragment, 또는
   agent/skill)를 찾아 수정한 후 `dx-agentic-gen generate`를 실행하세요.
3. **독립 소스** — 위 두 카테고리에 해당하지 않는 모든 파일 (`docs/source/`,
   `source/docs/`, `tests/`, 서브 프로젝트의 `README.md` 등)
   → 직접 수정 가능. 수정 후 `dx-agentic-gen check`를 한 번 실행하여 예상치
   못한 drift가 없는지 확인하세요.

**Anti-pattern**: 분류 없이 바로 파일을 수정하는 것. 해당 파일이 generator
output인지 확실하지 않으면, 수정 전후에 `dx-agentic-gen check`를 실행하세요
— check가 수정 내용을 덮어쓰면 해당 파일은 generator가 관리하는 파일이므로
`.deepx/` source를 통해 수정해야 합니다.

Pre-commit hook이 generator output 무결성을 강제합니다: 생성된 파일이
최신이 아니면 `git commit`이 실패합니다. Hook 설치:
```bash
tools/dx-agentic-dev-gen/scripts/install-hooks.sh
```

이 게이트는 `.deepx/` 파일이 작업의 *주요 산출물*인 경우(규칙 추가, 플랫폼 sync,
KO 번역 생성, agents/skills 수정)에 적용됩니다. 기능 구현 중 `.deepx/`에 단순
한 줄 수정이 발생하는 경우에는 적용되지 않습니다.
