# Ultralytics Retrain + Evaluate (domain optimization) → DeepX

> How to **adapt a base YOLO model to a specific domain** with the Ultralytics Python
> package and **evaluate it fairly** — both the PyTorch model (fp32) and its DeepX
> `.dxnn` (INT8 on DX-M1). Pairs with [`ultralytics-deepx-export.md`](./ultralytics-deepx-export.md)
> (the `format=deepx` compile step). Use this for "retrain on my dataset / optimize for
> my domain / measure accuracy + FPS" requests.

> **Get the latest knowledge first (do not fabricate APIs).** Ultralytics evolves. Before
> writing training/eval code, read the current docs:
> - Local clone (preferred): `git clone https://github.com/ultralytics/ultralytics` then read
>   `docs/en/modes/train.md`, `docs/en/modes/val.md`, `docs/en/modes/benchmark.md`,
>   `docs/en/datasets/detect/*.md`, and `ultralytics/cfg/datasets/*.yaml`.
> - Or web search "ultralytics train mode" / "ultralytics val mAP" / the dataset name.
> The snippets below are a current-as-of-2026-06 snapshot; verify against the above.

## The base model and its domain

Stock `yolo26n.pt` (like other Ultralytics release weights) is **COCO-pretrained** — 80
general everyday-object classes (person, car, dog, …). It is a *general-purpose* detector
and performs poorly on **domain-specific** classes it never saw (e.g. wildlife species,
defect types, PCB components). Domain optimization = **fine-tune on a labeled dataset of
the target domain** so the model detects the domain's classes.

## 1. Dataset (YAML)

Detection datasets use an Ultralytics YAML (`path`, `train`, `val`, `nc`, `names`):

```yaml
# my_domain.yaml
path: /abs/or/rel/dataset_root
train: images/train
val: images/val
nc: 4
names: [buffalo, elephant, rhino, zebra]
```

- **Built-in datasets auto-download** on first use (no manual download): e.g.
  `african-wildlife.yaml`, `brain-tumor.yaml`, `signature.yaml`, `VOC.yaml`, `coco128.yaml`.
  Their YAMLs live in `ultralytics/cfg/datasets/`.
- **Custom dataset**: point `data=` at your own YAML; images in `images/`, YOLO-format
  labels (`class cx cy w h`, normalized) in `labels/` mirroring the split dirs.

## 2. Retrain (fine-tune) on the domain — local GPU

```python
from ultralytics import YOLO

model = YOLO("yolo26n.pt")                      # base COCO weights
results = model.train(
    data="african-wildlife.yaml",               # or your custom my_domain.yaml
    epochs=40,                                   # modest count fine-tunes quickly
    imgsz=640,
    batch=16,
    device=0,                                    # local GPU; "cpu" if none
)
# best weights: runs/detect/train*/weights/best.pt
```

```bash
yolo detect train model=yolo26n.pt data=african-wildlife.yaml epochs=40 imgsz=640 device=0
```

The retrained head has `nc = <#domain classes>` (e.g. 4) instead of COCO's 80.

## 3. Evaluate accuracy (mAP) — `model.val()`

```python
m = YOLO("runs/detect/train/weights/best.pt").val(data="african-wildlife.yaml", imgsz=640)
print(m.box.map, m.box.map50, m.box.map75)      # mAP50-95, mAP50, mAP75
print(m.box.maps)                                # per-class mAP50-95
# m.speed -> {'preprocess','inference','postprocess'} ms/img → FPS = 1000/inference
```

- **mAP50-95** is the primary accuracy metric; report mAP50 + per-class too.
- **FPS** = `1000 / m.speed["inference"]` (single-image latency), measured on an idle host.

## 4. Export to DeepX + evaluate the `.dxnn`

Export each `.pt` with `format=deepx` (see `ultralytics-deepx-export.md`), then run the
**same `model.val()`** on the exported model directory — the Ultralytics DeepX backend
runs INT8 inference on the DX-M1 NPU, so the reported mAP/FPS are the on-device numbers:

```python
YOLO("yolo26n.pt").export(format="deepx")                       # → yolo26n_deepx_model/
m = YOLO("yolo26n_deepx_model").val(data="african-wildlife.yaml", imgsz=640)  # NPU mAP+FPS
```

## 5. The fair comparison (base vs retrained × fp32 vs INT8)

For a domain-optimization report, measure **four** points so accuracy *and* the
quantization effect are both visible:

| Model | Form | Device | What it shows |
|---|---|---|---|
| base `yolo26n` | `.pt` (fp32) | GPU | the general model's domain accuracy (usually ~0 on unseen classes) |
| base `yolo26n` | `.dxnn` (INT8) | DX-M1 NPU | on-device baseline FPS/accuracy |
| retrained | `.pt` (fp32) | GPU | the upper-bound domain accuracy after fine-tuning |
| retrained | `.dxnn` (INT8) | DX-M1 NPU | the deployable result; INT8 vs fp32 gap = quantization loss |

Report Δaccuracy (retrain vs base) and Δspeed; note that a smaller `nc` head often makes
the domain `.dxnn` **faster** on the NPU than the 80-class stock model.

## 6. Relocatable packaging (HARD GATE — showcases)

A generated retrain→eval showcase MUST be **self-contained and relocatable**: moving the
folder (or running it from a fresh checkout) and re-running `run.sh` MUST work with NO edit
to any file. Two recurring violations and the rule:

- **NEVER serialize absolute paths** into data files (`train_result.json`, configs,
  `results.json`). An absolute `best_pt`/`save_dir` into the build session/worktree breaks
  the instant the showcase is copied (the ppe `retrained best.pt missing` regression). If you
  must persist training metadata, store **paths relative to the script dir**
  (`Path(__file__).resolve().parent`).
- **Prefer regenerate-if-missing over skip-if-metadata-exists.** The robust pattern
  (wildlife): a single `pipeline.py` that, when weights are absent, trains from scratch and
  copies `best.pt` into the showcase dir under a stable relative name
  (`shutil.copy(best, HERE / "<domain>_yolo26n.pt")`), then exports + evals using only
  `HERE / <relative>` paths. `run.sh` simply runs the pipeline (no `if train_result.json`
  short-circuit that points at a vanished absolute path).
- If shipping pre-trained weights instead of retraining, bundle the `.pt` in the showcase
  dir and reference it relative to the script — never an absolute build-worktree path.
- **Annotated sample image: pick the BEST-detections val image, not a fixed/middle index.**
  The showcase card shows `sample_detect.jpg`; a busy, representative scene reads far better
  than `imgs[len//2]` (which lands on a near-empty frame). Scan the val set once on the
  retrained model and keep the image with the most boxes (deterministic given fixed
  weights + val set):
  ```python
  sample_model = YOLO(str(retrained_pt))
  sample_src, best_n = imgs[0], -1
  for p in imgs:
      nb = len(sample_model.predict(source=str(p), imgsz=IMGSZ, conf=0.25,
                                    device=0, save=False, verbose=False)[0].boxes)
      if nb > best_n: sample_src, best_n = p, nb
  # then predict sample_src with save=True → sample_detect.jpg
  ```

`dx-showcase-gen verify` fails a showcase whose committed files (incl. `*.json`) contain a
build-session/absolute path.

## Constraints / notes

- Export/compile is **x86-64 Linux only**; **detection** task; **INT8 enforced** (see
  `ultralytics-deepx-export.md`). Training itself runs on GPU/CPU on any platform.
- `dx_engine` (for NPU `.dxnn` eval) is a **dx_rt** artifact — build dx-runtime
  (`install.sh --all --exclude-app --exclude-stream`), not pip. See the deploy section of
  `ultralytics-deepx-export.md`.

## References

- Ultralytics: `docs/en/modes/train.md`, `val.md`, `benchmark.md`, `docs/en/datasets/detect/`
- DeepX export: `ultralytics-deepx-export.md` · compile: `dxcom-cli.md`/`dxcom-api.md`
