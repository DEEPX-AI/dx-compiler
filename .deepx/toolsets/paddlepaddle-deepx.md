# PaddlePaddle Ecosystem → DeepX NPU Reference

> How to build apps on the **PaddlePaddle OCR/document ecosystem** running on the
> DeepX **DX-M1 NPU**, using DEEPX's integrated forks:
> **PaddleOCR-deepx** (text detection + recognition, PP-OCRv5 / PP-StructureV3) and
> **RapidDoc** (PDF → Markdown document parsing). Read this BEFORE improvising a
> PaddleOCR/RapidDoc integration from the upstream repos.

## Canonical sources (READ the DEEPX branch — not upstream main)

| Repo | DEEPX branch | What it provides |
|---|---|---|
| [DEEPX-AI/PaddleOCR-deepx](https://github.com/DEEPX-AI/PaddleOCR-deepx) | **`deepx`** | PaddleOCR 3.0 (PP-OCRv5 det+rec, PP-StructureV3) with DX-M1 NPU inference. |
| [DEEPX-AI/RapidDoc](https://github.com/DEEPX-AI/RapidDoc) | **`rapid_doc_deepx`** | PDF/scanned-doc → **Markdown + JSON** via a 7-stage NPU pipeline (layout, OCR det/rec, table, formula). See `README_DEEPX_EN.md`. |
| Upstream (reference only) | [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) · [RapidDoc](https://github.com/RapidAI/RapidDoc) | API/model background; **no DeepX NPU path** — do not follow for NPU. |

**Get latest knowledge** (the DEEPX integration evolves): clone the DEEPX branch and read
its `README*_DEEPX*.md`, `deepx_scripts/`, and `demo/` before generating code —
```bash
git clone -b deepx https://github.com/DEEPX-AI/PaddleOCR-deepx.git
git clone -b rapid_doc_deepx https://github.com/DEEPX-AI/RapidDoc.git   # then read README_DEEPX_EN.md
```

## Platform constraints (HARD)

- **DX-M1 NPU** target; **x86-64 Linux** host with the DEEPX runtime (`dx_rt` / `dx_engine`) installed.
- Models are **DEEPX-compiled** artifacts shipped/downloaded by the DEEPX fork — do NOT
  re-compile PaddleOCR/RapidDoc models by hand. Run the fork's **`./setup.sh`** (downloads
  the prebuilt `onnx_models/` + `dxnn_models/`); hand-compiling each `.dxnn` is the known
  cause of the build deadlock.
- The DEEPX runtime env MUST be sourced (DX-RT thread/dynamic-CPU env vars) before inference.
- Output isolation still applies: generated apps go to `dx-agent-dev/<session_id>/`.

## A. RapidDoc — PDF → Markdown on the NPU

Setup (from the `rapid_doc_deepx` branch checkout):
```bash
pip install -r requirements.deepx.txt && pip install -e .   # deps + editable package
# Download the prebuilt NPU models — do NOT hand-compile any .dxnn. The fork's
# setup.sh → setup_assets() → setup_sample_models.sh fetches the required onnx_models/
# + dxnn_models/ payloads (skips the download if they already exist):
./setup.sh                                        # host mode auto-detected; --force-remove-models to refetch
source ./deepx_scripts/set_env.sh 1 2 1 3 2 4     # DX-RT env: INTER/INTRA op threads, dynamic CPU, task load, NFH workers
export DXNN_DEVICES=0                              # NPU device(s); 0,1,2,3 for multi-NPU (auto-detected if unset)
```
**Model acquisition = `./setup.sh`, never a `dxcom` compile.** The deadlock class of
failure (agent stalls downloading/compiling each model by hand) is avoided entirely:
`./setup.sh` is the one turnkey step that provisions every onnx+dxnn the pipeline needs.

The fork's `demo/demo_offline.py` shows the pipeline (parse-method `auto|txt|ocr`,
`--finegrained` 7-stage streaming, `--hybrid` multi-NPU). **When BUILDING an app, do NOT
ship/run that demo** — generate a **standalone entry** that imports the fork's pipeline API
(`rapid_doc.backend.pipeline.pipeline_analyze.doc_analyze`, `rapid_doc.data.data_reader_writer`)
and **vendor the `rapid_doc` package** into the app dir. See the app-build companion
`dx-runtime/dx_app/.deepx/toolsets/paddleocr-rapiddoc-app.md` (sections A/B + "Mandatory
deliverables"). Output: Markdown + JSON (preserves layout/headings/tables; `--no-formula`
keeps formula regions as cropped images).

## B. PaddleOCR-deepx — OCR inference (build a video/webcam app)

PaddleOCR-deepx exposes PP-OCRv5 (detection + recognition) and PP-StructureV3 on the NPU.
Upstream supports image/PDF input only — a **video-file + webcam OCR app** is built by
wrapping a frame-capture loop (OpenCV) around the fork's NPU OCR predictor:
```python
import cv2
from paddleocr import PaddleOCR                 # DEEPX fork; uses the DX-M1 NPU models
ocr = PaddleOCR(use_doc_orientation_classify=False, use_doc_unwarping=False)  # detect+recognize

def open_source(src):                            # src: video file path, or webcam index (int)
    return cv2.VideoCapture(int(src) if str(src).isdigit() else src)

cap = open_source(args.source)                   # --source video.mp4  OR  --source 0 (webcam)
while True:
    ok, frame = cap.read()
    if not ok: break
    res = ocr.predict(frame)                     # per-frame NPU OCR → boxes + text + scores
    # draw res boxes/text on frame; write to --output mp4 and/or cv2.imshow
```
- Detect-only vs detect+recognize: configure via the PaddleOCR constructor flags (mirror the fork's demo).
- For real-time webcam, run detection at the NPU's input resolution and skip frames if needed.
- Save an annotated sample frame (`sample_detect.jpg`) for the showcase card.

## Example end-user build prompts (canonical)

These are the prompts a **real user** types — short, goal-only, and deliberately
**naming NO toolset path, file, repo branch, or env script.** The agent is expected to
route to THIS toolset from the task vocabulary alone ("OCR app / video / webcam",
"PDF to Markdown / document parsing", "DEEPX DX-M1 NPU"), then read it and the cloned
DEEPX-branch docs to fill in `set_env.sh`, `DXNN_DEVICES`, `./setup.sh`, `demo/demo_offline.py`,
etc. **Do NOT pad the prompt with operator scaffolding** (toolset paths, branch names, file
lists) — proving the skill + routing supply that is the point. Headless/autopilot runs may
append "work autonomously to completion; submit actual artifacts, not just a plan. Respond
in English." (trimmed from the showcase README).

**1) Video-file + webcam OCR inference app**
> Build an OCR inference app whose text detection + recognition runs on the DEEPX DX-M1 NPU.
> The app must accept BOTH a **video file** (`--source <path.mp4>`) and a **live webcam**
> (`--source <camera_index>`), run NPU OCR on each frame, overlay detected text boxes +
> recognized strings, and write an annotated output video (optionally show a live window).
> Save one annotated sample frame as `sample_detect.jpg`. Provide setup.sh, run.sh, and a
> short README reporting the measured per-frame latency / FPS on the NPU.

**2) PDF → Markdown app**
> Build a PDF-to-Markdown app whose document-parsing pipeline (layout analysis + OCR +
> table/formula recognition) runs on the DEEPX DX-M1 NPU. Input a PDF (digital or scanned),
> output structured Markdown (+ JSON) preserving headings and tables. Support
> `--parse-method auto|txt|ocr`. Provide setup.sh, run.sh, a sample input PDF + its rendered
> Markdown output (`sample_output.md`), and a README reporting NPU stage timings.

## Anti-patterns (STOP)

- Following upstream PaddleOCR/RapidDoc `main` for the NPU path — it has **no DeepX backend**.
  Always use the DEEPX `deepx` / `rapid_doc_deepx` branches.
- Hand-compiling PaddleOCR/RapidDoc models to `.dxnn` with `dxcom` — run the fork's
  **`./setup.sh`** to download the prebuilt `onnx_models/` + `dxnn_models/`. Manual
  per-model download/compile is what previously **deadlocked** the build.
- Launching the model download/compile as a **background task** in a headless run — a
  `claude -p` process can't resume on the completion notification, so it hangs forever.
  Run `./setup.sh` in the **foreground** (it is the single blocking provisioning step).
- Running inference without sourcing the DX-RT env (`deepx_scripts/set_env.sh`) → device errors.
- Claiming NPU results without the runtime actually initialized (run the suite sanity check first).
