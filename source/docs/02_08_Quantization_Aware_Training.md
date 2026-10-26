# Q-Master (Quantization-Aware Training)

**Q-Master** is the DX-COM feature that runs **Quantization-Aware Training (QAT)**. It fine-tunes the model while simulating INT8 quantization, so it can recover accuracy that post-training quantization (PTQ) alone cannot.

**In short:** add a `qmaster` block to your PTQ JSON, run `dxcom` as usual, and get a fine-tuned `.dxnn`. You do not need labels, a separate training script, or a different command.

Q-Master reuses the **same JSON configuration** as a normal compile. Add a `qmaster` block and DX-COM switches from PTQ to Q-Master automatically — no extra command-line flag is needed.

!!! note "Version Support"
    Q-Master is available from **DX-COM v2.4.0**. From **v2.5.0** the Python API takes
    `qmaster=QMasterConfig(...)`, and Segmentation Q-Master is available.
    See [Version History](#version-history).

---

## When to Use Q-Master

```
Compile with PTQ  ─►  Accuracy acceptable?  ── yes ─►  Done
                              │ no
                              ▼
        Tune PTQ first (02_07 Quantization Tuning Workflow)
                              │ still not enough
                              ▼
                      Use Q-Master (this chapter)
```

| | PTQ | Q-Master (QAT) |
|---|---|---|
| Needs training data | Calibration images only (about 100) | Training images (hundreds to thousands) |
| Needs a GPU | No | **Yes** (CUDA GPU, default `cuda:0`) |
| Compile time | Minutes | Minutes to hours, depending on model and data size |
| Changes model weights | No | Yes (fine-tuned) |
| Typical use | First attempt | Accuracy still below target after PTQ tuning |

!!! tip "Checklist before you start"
    - [ ] The model already compiles with PTQ using the same JSON config.
    - [ ] A CUDA GPU is available to PyTorch (`python -c "import torch; print(torch.cuda.is_available())"` prints `True`). To pick a specific GPU, set `CUDA_VISIBLE_DEVICES` and keep `device` at `"cuda:0"`.
    - [ ] A folder of representative images is set in `default_loader.dataset_path` (the images are searched recursively by `file_extensions`). Use images similar to your real input, **not** the test set you evaluate on.
    - [ ] You have a way to measure accuracy before and after (compare the PTQ `.dxnn` with the Q-Master `.dxnn` on the same evaluation set).

---

## Quick Start

### 1. Add a `qmaster` block to your config

Start from the JSON you already use for PTQ and append a `qmaster` block. Example for an ImageNet classifier:

```json
{
  "inputs": { "input": [1, 3, 224, 224] },
  "calibration_num": 100,
  "calibration_method": "ema",
  "default_loader": {
    "dataset_path": "/datasets/ILSVRC2012/train",
    "file_extensions": ["jpeg", "jpg", "png", "JPEG"],
    "preprocessings": [
      { "resize": { "mode": "default", "size": 256 } },
      { "centercrop": { "width": 224, "height": 224 } },
      { "convertColor": { "form": "BGR2RGB" } },
      { "div": { "x": 255 } },
      { "normalize": { "mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225] } },
      { "transpose": { "axis": [2, 0, 1] } },
      { "expandDim": { "axis": 0 } }
    ]
  },
  "qmaster": {
    "batch_size": 16,
    "train_limit": 2000,
    "val_limit": 200,
    "epochs": 10
  }
}
```

!!! note "One preprocessing pipeline"
    `inputs`, `calibration_*`, and `default_loader` work exactly as in
    [JSON File Configuration](02_05_JSON_File_Configuration.md). `default_loader.preprocessings`
    is the single source of truth for both calibration and Q-Master training data —
    do **not** redefine it inside `qmaster`.

!!! warning "Apply `convertColor` again at inference"
    `convertColor` is not integrated into the NPU graph (it is listed under `Skipped nodes` in
    `compiler.log`). Your inference code must apply the same `BGR2RGB` conversion before feeding
    the compiled model; otherwise inference sees a different channel order from calibration and
    training, and accuracy drops without any error.

### 2. Compile

```bash
dxcom -m model.onnx -c config_with_qmaster.json -o output/
```

### 3. Check the result

- `output/<model>.dxnn` — the compiled model.
- `output/qat_checkpoint/qat_checkpoint.qxnn` — the best checkpoint (lowest validation loss).
- `compiler.log` — starts with a **Q-MASTER CONFIG** box listing the values actually used. **Always check it** (see [Pitfalls](#pitfalls)).

### 4. What to expect

- Training time grows with `epochs × train_limit` and model size. Run the smoke test below first to estimate speed.
- Q-Master does not guarantee a gain. Compare accuracy against your PTQ result; if it does not improve, see [Troubleshooting](#troubleshooting).
- The original ONNX file is never modified.

### 5. Smoke test first (recommended)

Before a long run, set `"fast_run": true` inside `qmaster`. It trains for 1 epoch × 1 batch to prove the pipeline works end to end. The resulting accuracy is **not meaningful**; remove `fast_run` for the real run.

---

## How Q-Master Works

A Q-Master compile runs three steps:

1. **Calibration** — estimates initial quantization parameters (shared with PTQ).
2. **Training (Stage 1)** — fine-tunes the model with simulated quantization. The best checkpoint (lowest validation loss) is saved to `qat_checkpoint/qat_checkpoint.qxnn`. Stage 1 trains at the `batch_size` you set.
3. **Compilation (Stage 2)** — converts the trained weights into the NPU binary (`*.dxnn`), always at batch size 1.

### Knowledge Distillation (KD)

By default Q-Master uses the original floating-point (FP32) model as a **teacher**, and trains the quantized model (the **student**) to reproduce the teacher's output. With the defaults (`kd_loss = "mse"`, `kd_alpha = 1.0`) training uses the teacher output only and **no ground-truth labels**, so unlabeled images work.

---

## Recipes

Copy the closest recipe and change only what you need. All keys are described in the [Parameter Reference](#parameter-reference).

### A. Default (no labels needed)

```json
"qmaster": { "batch_size": 16, "train_limit": 2000, "val_limit": 200, "epochs": 10 }
```

Teacher-only MSE distillation. Good first attempt for any model. Images need no labels and no particular folder layout.
If `train_limit + val_limit` is larger than the number of images found, all available images are used.

### B. Classification with labels (KD + cross-entropy)

```json
"qmaster": {
  "batch_size": 16,
  "train_limit": 5000,
  "val_limit": 500,
  "criterion": "cross_entropy",
  "kd_loss": "kl_div",
  "kd_temperature": 2.0,
  "kd_alpha": 0.5
}
```

Blends the teacher signal (`kd_alpha`) with the label loss (`1 - kd_alpha`).
Requires an ImageFolder layout (`<dataset_path>/<class_name>/<image>`).

!!! warning "Labels come from folder names"
    Class indices are built from the class folders **found in the subset actually loaded**
    (`train_limit + val_limit`). If a class is missing from that subset, label indices shift
    and the label loss trains toward the wrong classes. Make sure every class is present,
    or use recipe A.

### C. Embedding / encoder models (e.g. CLIP image encoder)

```json
"qmaster": { "encoder_mode": true, "kd_alpha": 1.0 }
```

Tracks **cosine similarity** instead of classification accuracy.

### D. Zero-shot classification (e.g. CLIP)

```json
"qmaster": {
  "zeroshot_weights_path": "/path/to/text_embedding.npy",
  "use_kd": false
}
```

Zero-shot cannot be combined with `use_kd` or `encoder_mode`.

### E. Segmentation (v2.5.0+)

```json
"qmaster": {
  "task_type": "segmentation",
  "seg_root": "/path/to/dataset_root",
  "seg_pairs_train": "/path/to/dataset_root/lists/train.txt",
  "seg_pairs_val": "/path/to/dataset_root/lists/val.txt",
  "seg_ignore_index": 255,
  "seg_binary": true,
  "use_kd": false
}
```

See [Segmentation Parameters](#segmentation-parameters).

### F. Out of GPU memory

```json
"qmaster": { "batch_size": 4, "gradient_accumulation_steps": 4 }
```

Effective batch size stays `4 × 4 = 16`.

If CUDA runs out of memory at your `batch_size`, DX-COM automatically retries Stage 1 at batch size 1. This succeeds but is **much slower**, so lower `batch_size` yourself to stay fast.

### G. Re-compile without re-training / continue training

Use `stage1_mode` — see [Re-using a Checkpoint](#re-using-a-checkpoint).

---

## Parameter Reference

Every key is optional. Omitted keys use the defaults below.

### Data and Device

| Parameter | Default | Description |
|-----------|---------|-------------|
| `batch_size` | `1` | Training batch size for Stage 1. Use `> 1` (e.g. `16`) for faster, more stable training. Models whose inputs have no batch axis of 1 (e.g. fixed-length text encoders) automatically fall back to `1`. |
| `num_workers` | `4` | DataLoader workers. |
| `train_limit` | `500` | Number of training images used. **The default is small (smoke-test scale); raise it for real training.** |
| `val_limit` | `50` | Number of validation images, reserved **before** training images are taken from the same pool. |
| `train_drop_last` / `val_drop_last` | `true` / `false` | Drop the last incomplete batch. |
| `device` | `"cuda:0"` | Training device. Select the physical GPU with `CUDA_VISIBLE_DEVICES`. |
| `train_cpu_fp` | `false` | Also train the CPU (non-NPU) parts of the model and write the trained weights back into the compiled model. When `false`, CPU subgraph weights stay frozen. |

### Training Loop

| Parameter | Default | Description |
|-----------|---------|-------------|
| `epochs` | `30` | Maximum epochs. |
| `lr` | `1e-5` | Learning rate. Lower it (e.g. `5e-6`) if accuracy gets worse from the first epoch. |
| `optimizer` | `"adamw"` | `"adamw"` or `"sgd"`. |
| `weight_decay` | `1e-4` | Optimizer weight decay. |
| `scheduler` | `null` | `null`, `"cosine"`, or `"step"`. |
| `scheduler_step_size` | `max(1, (epochs - warmup_epochs) // 3)` | Epoch interval for `"step"` only. |
| `warmup_epochs` | `0` | Linear LR warmup epochs. |
| `max_grad_norm` | `1.0` | Gradient clipping. |
| `use_amp` | `true` | Mixed-precision training. |
| `gradient_accumulation_steps` | `1` | Effective batch = `batch_size × this`. |
| `early_stopping_patience` | `5` | Stop after N epochs without improvement on validation loss. `null` disables. Requires validation data. |
| `early_stopping_delta` | `1e-3` | Minimum improvement counted as progress. |
| `save_best_model` | `true` | Save the checkpoint with the lowest validation loss. |
| `freeze_bn_after` | `null` | From this epoch on, freeze BatchNorm **and** stop updating activation quantization ranges. See [Pitfalls](#pitfalls). |

### Loss and Knowledge Distillation

The loss is `kd_alpha × KD loss + (1 − kd_alpha) × task loss`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `use_kd` | `true` | Use the FP teacher. |
| `kd_loss` | `"mse"` | `"mse"`, `"kl_div"`, `"cosine"`, `"bce"`, `"smooth_l1"`, `"ciou"`, `"giou"`. |
| `kd_alpha` | `1.0` | KD weight in `[0, 1]`. At `1.0` the task loss is **not computed**. |
| `kd_temperature` | `4.0` | Softening temperature. Used only by `"kl_div"` and `"bce"`. |
| `kd_box_format` | `"xyxy"` | Box format for `"ciou"` / `"giou"`: `"xyxy"`, `"cxcywh"`, `"xywh"`. |
| `criterion` | `"mse"` | Task loss: `"mse"` or `"cross_entropy"` (`"seg_ce"` for segmentation). Used only when `kd_alpha < 1.0` or `use_kd = false`. `"cross_entropy"` switches to the labeled (ImageFolder) loader. |
| `label_smoothing` | `0.0` | Cross-entropy only. |

Choosing the loss:

| Goal | Settings |
|------|----------|
| No labels available | defaults (`kd_alpha = 1.0`, `kd_loss = "mse"`) |
| Classification with labels | `criterion = "cross_entropy"`, `kd_loss = "kl_div"`, `kd_alpha = 0.5–0.7` |
| No teacher | `use_kd = false`, plus a `criterion` |

### Mode Switches

| Parameter | Default | Description |
|-----------|---------|-------------|
| `encoder_mode` | `false` | Track cosine similarity instead of accuracy (embedding/encoder models). Does not disable the task loss by itself; keep `kd_alpha = 1.0`. |
| `zeroshot_weights_path` | — | `.npy` text-embedding file for zero-shot models. |
| `stage1_mode` | `"fresh"` | `"fresh"`, `"resume"`, `"skip"`. See [Re-using a Checkpoint](#re-using-a-checkpoint). |
| `fast_run` | `false` | Smoke test: 1 epoch × 1 batch, 100 train / 10 val images. Not accuracy-meaningful. |

### Segmentation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `task_type` | `"classification"` | Set `"segmentation"` for dense `(image, mask)` data. |
| `seg_root` | — | Root directory for the pair lists. |
| `seg_pairs_train` / `seg_pairs_val` | — | Text files, one `<image_path> <mask_path>` per line, relative to `seg_root`. |
| `seg_ignore_index` | `255` | Label value excluded from loss and metric. |
| `seg_binary` | `true` | Binary (foreground/background) segmentation. Set `false` for multi-class. |

With `task_type = "segmentation"`, `criterion` defaults to `"seg_ce"`. Masks are not passed through `preprocessings`; only the image is.

---

## Re-using a Checkpoint

Training can take a long time. `stage1_mode` controls what happens when `output/qat_checkpoint/qat_checkpoint.qxnn` already exists:

| `stage1_mode` | Behavior | Use when |
|---------------|----------|----------|
| `"fresh"` (default) | Train from the start and overwrite the checkpoint. | First run. |
| `"resume"` | Load the checkpoint weights and continue training (optimizer and epoch counter restart). If no checkpoint exists, trains from scratch with a warning. | Fine-tune further with a lower `lr`. |
| `"skip"` | Skip training and run Stage 2 (compilation) only. The checkpoint **must** exist. | Re-generate the `.dxnn` (e.g. after a compiler update). |

```json
"qmaster": { "stage1_mode": "skip" }
```

To start from a checkpoint made elsewhere, copy it to `<output_dir>/qat_checkpoint/qat_checkpoint.qxnn` first.

---

## Python API

```python
import dx_com

# A qmaster block in the config JSON triggers Q-Master.
dx_com.compile(model="model.onnx", config="config_with_qmaster.json", output_dir="output/")
```

!!! note "Configure Q-Master in the JSON"
    Set all Q-Master options in the JSON `qmaster` block, as in the [Quick Start](#quick-start).
    To re-compile from a checkpoint, use `stage1_mode` in the JSON
    (see [Re-using a Checkpoint](#re-using-a-checkpoint)).

!!! warning "Changed in v2.5.0"
    The flat arguments `quantization_mode`, `qat_config`, `qat_skip_training`, and
    `qat_resume_from_checkpoint` were replaced by the single `qmaster` argument.
    Do not pass any of the four removed arguments.

!!! note "`fast_run` is a config key"
    Set `"fast_run": true` inside the `qmaster` block; it is not a `compile()` argument.

!!! note "Not interchangeable with `quant_diagnosis`"
    The `.qxnn` from `quant_diagnosis` (see [Quantization Tuning Workflow](02_07_Quantization_Tuning_Workflow.md))
    is a different file from the Q-Master `qat_checkpoint.qxnn`.

---

## Output Files

| File | Description |
|------|-------------|
| `<output_dir>/*.dxnn` | Compiled NPU binary (the deliverable). |
| `<output_dir>/qat_checkpoint/qat_checkpoint.qxnn` | Best training checkpoint. Input for `stage1_mode = "resume"/"skip"`. |
| `<output_dir>/compiler.log` | Full log, including the **Q-MASTER CONFIG** box and per-epoch metrics. |

---

## Pitfalls

!!! warning "Unknown keys are silently ignored"
    A misspelled key (e.g. `learning_rate`) does **not** raise an error; the default is used
    instead. Open `compiler.log` and check the **Q-MASTER CONFIG** box to confirm the values
    that were actually applied.

!!! warning "Confirm Q-Master actually ran"
    After compiling, open `compiler.log` and check that the **Q-MASTER CONFIG** box and
    per-epoch training lines appear, and that no `falling back` message is present. If
    training did not run, the result is plain PTQ.

!!! warning "Dataset path falls back silently"
    If `default_loader.dataset_path` is missing or invalid, DX-COM does **not** fail. It falls
    back to a built-in default ImageNet location, so training may silently use unintended data.
    Verify the dataset path in the log.

!!! warning "Best checkpoint is chosen by validation loss"
    The saved checkpoint has the lowest **validation loss**, which includes the KD term. It can
    differ from the checkpoint with the best Top-1 accuracy.

!!! warning "BatchNorm / observer freezing"
    `freeze_bn_after` freezes BatchNorm **and** stops updating activation quantization ranges
    from the given epoch. `freeze_bn_after = 0` freezes from the very first epoch (after one
    warm-up pass), which can make the loss diverge to `nan`. Leave it `null` unless you need
    it, and then start from a later epoch.

!!! warning "Default `train_limit` is small"
    `train_limit = 500` is meant for quick checks. Use thousands of images for a real run.

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| CUDA out of memory | `batch_size` too large for the GPU | Lower `batch_size`, raise `gradient_accumulation_steps`. The automatic batch-1 fallback works but is slow. |
| Loss becomes `nan` | `freeze_bn_after = 0`, `lr` too high | Set `freeze_bn_after` to `null` or a later epoch; lower `lr`. |
| Validation loss is worst at later epochs; best epoch is 1 | `lr` too high | Lower `lr`; try `stage1_mode = "resume"` with a smaller `lr`. |
| Training stops very early | `early_stopping_patience` too small / validation too noisy | Raise `patience`, raise `val_limit`. |
| Accuracy not better than PTQ | Too little data / loss mismatch | Raise `train_limit`; for classification with labels use recipe B. |
| Label loss trains the wrong classes | A class is missing from the subset | Check class folders; raise `train_limit`; or use recipe A. |
| Training used unexpected data | `dataset_path` invalid → silent fallback | Check the dataset path in `compiler.log`. |
| Settings seem to have no effect | Key misspelled or in the wrong block | Check the **Q-MASTER CONFIG** box in `compiler.log`. |
| Training metrics are good but `.dxnn` accuracy dropped | Loss in a compiler stage that training cannot see | Compare the `.dxnn` with the original model on the same evaluation set and report the gap to DEEPX. |

---

## FAQ

**Do I need labeled data?**
No. The default recipe distills from the FP32 model and uses images only. Labels are needed only for recipe B.

**Can I use my own dataset instead of ImageNet?**
Yes. Point `default_loader.dataset_path` at your images. Use the same preprocessing as in PTQ.

**Can I use the calibration images for training?**
Yes, but more varied images generally give better results. Do not train on the images you use to report final accuracy.

**Is the compiled `.dxnn` different from a PTQ one?**
Same format and runtime. Only the weights and quantization parameters are different.

**Training finished but I want to try another setting. Do I need to start over?**
Use `stage1_mode = "resume"` to continue from the saved checkpoint, or `"fresh"` with a new `output_dir` to start clean.

**I only want to rebuild the `.dxnn` (e.g. new DX-COM version).**
Use `stage1_mode = "skip"` with the existing checkpoint.

---

## Version History

| Version | Change |
|---------|--------|
| v2.4.0 | Q-Master (QAT) added via the JSON `qmaster` block. |
| v2.5.0 | Python API: `qmaster=QMasterConfig(...)`; `qat_*` arguments removed. Segmentation Q-Master (`task_type = "segmentation"`). |

---

## Related Pages

- [JSON File Configuration](02_05_JSON_File_Configuration.md) — `inputs`, `calibration_*`, `default_loader`.
- [Execution of DX-COM](02_06_Execution_of_DX-COM.md) — CLI and Python API reference.
- [Quantization Tuning Workflow](02_07_Quantization_Tuning_Workflow.md) — tune PTQ before using Q-Master.
- [Change Log](Appendix_Change_Log.md).
