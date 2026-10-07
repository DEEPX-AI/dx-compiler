This chapter describes how to compile a model with **Quantization-Aware Training (QAT)** using **DX-COM**. QAT fine-tunes the model while simulating quantization, which can recover accuracy that is otherwise lost by post-training quantization (PTQ) alone.

QAT reuses the **same JSON configuration** as a normal (PTQ) compile. When the configuration file contains a `qmaster` block, `dx_com.compile()` automatically switches to QAT mode and runs the training pipeline using the same dataset and preprocessing settings as PTQ calibration.

!!! note "Version Support"
    QAT (the `qmaster` block) is supported in **DX-COM v2.4.0 and later**. From
    **v2.5.0**, the Python API drives QAT through the `qmaster=QMasterConfig(...)`
    argument (the earlier `qat_*` arguments were removed).

---

## How QAT Is Triggered

QAT is enabled by **adding a `qmaster` block** to the JSON configuration. No separate command-line flag is required.

- If the config contains a `qmaster` block → DX-COM runs **QAT** (Calibration → Training → Compilation).
- If the config has **no** `qmaster` block → DX-COM runs the normal **PTQ** compile.

```json
{
  "inputs": { "input.1": [1, 3, 224, 224] },
  "calibration_num": 100,
  "calibration_method": "ema",
  "default_loader": { "dataset_path": "/datasets/ILSVRC2012/train", "file_extensions": ["jpeg","jpg","png","JPEG"], "preprocessings": [ "..." ] },
  "qmaster": { "epochs": 30, "lr": 1e-5, "use_kd": true }
}
```

!!! note "Reuses Your Existing Config"
    `inputs`, `calibration_*`, and `default_loader` work exactly as described in
    [JSON File Configuration](02_05_JSON_File_Configuration.md). The image
    preprocessing pipeline (`default_loader.preprocessings`) is the single source of
    truth for both calibration and QAT training data — you do **not** redefine it inside `qmaster`.

---

## Compilation Stages

A QAT compile runs three stages automatically:

1. **Calibration** — estimates initial quantization parameters (shared with PTQ).
2. **Training (Stage 1)** — runs the QAT fine-tuning loop. The best checkpoint (lowest validation loss) is saved to `qat_checkpoint/qat_checkpoint.qxnn`.
3. **Compilation (Stage 2)** — converts the trained weights into the NPU binary (`*.dxnn`).

---

## The `qmaster` Block

The `qmaster` block holds **training hyperparameters only**. Every key is optional; omitted keys fall back to the defaults below.

### Parameter Quick Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `batch_size` | `1` | Training batch size. Also selects the internal compile path (see note below). Default `1` uses the single-shot path; set to `> 1` (e.g. `16`) to use the staged path recommended for most models. |
| `num_workers` | `4` | Number of DataLoader workers. |
| `train_limit` / `val_limit` | `500` / `50` | Number of training / validation samples (subset). |
| `device` | `"cuda:0"` | Training device. |
| `epochs` | `30` | Maximum number of training epochs. |
| `lr` | `1e-5` | Learning rate. |
| `optimizer` | `"adamw"` | Optimizer: `"adamw"` or `"sgd"`. |
| `criterion` | `mse` | Task loss: `mse` or `cross_entropy`. Applied when use_kd = false, or when use_kd = true and kd_alpha < 1.0 (task loss weight = 1 - kd_alpha). With the default use_kd = true and kd_alpha = 1.0, task loss is disabled and this value has no effect. |
| `scheduler` | `null` | LR scheduler: `null`, `"cosine"`, or `"step"`. |
| `scheduler_step_size` | `max(1, (epochs - warmup_epochs) // 3)` | Step interval (in epochs) for the `"step"` scheduler. Only used when `scheduler = "step"`. |
| `weight_decay` | `1e-4` | Optimizer weight decay. |
| `max_grad_norm` | `1.0` | Gradient-clipping max norm. |
| `use_amp` | `true` | Mixed-precision (AMP) training. |
| `warmup_epochs` | `0` | Scheduler warmup epochs. |
| `gradient_accumulation_steps` | `1` | Effective batch = `batch_size × this value`. |
| `early_stopping_patience` | `5` | Stop early after N epochs with no improvement. |
| `early_stopping_delta` | `1e-3` | Minimum improvement counted as progress. |
| `save_best_model` | `true` | Save the best (lowest val-loss) checkpoint. |
| `use_kd` | `true` | Enable Knowledge Distillation (FP teacher → quantized student). |
| `kd_loss` | `"mse"` | KD loss type. |
| `kd_alpha` | `1.0` | KD loss weight. The task loss is weighted by `1 - kd_alpha`, so the default `1.0` trains with **KD only** (task loss disabled). |
| `kd_temperature` | `4.0` | KD softening temperature. |
| `encoder_mode` | `false` | Track accuracy as **cosine similarity** instead of classification accuracy (for embedding/encoder-style models). Does not by itself disable the task loss — combine with `kd_alpha = 1.0` for pure KD training. |
| `freeze_bn_after` | `null` | Freeze BatchNorm from the given epoch. See warning below. |
| `train_cpu_fp` | `false` | Keep the FP teacher on CPU to save GPU memory (slightly slower). |
| `fast_run` | `false` | Quick smoke test: 1 epoch × 1 batch. Result is **not** accuracy-meaningful. |

!!! note "Batch Size and the Internal Compile Path"
    `batch_size > 1` runs the **staged** path (recommended for most models);
    `batch_size = 1` runs the **single-shot** path. If a batched run is not possible
    for a given model, DX-COM automatically falls back to single-shot at batch size 1.

### Data and Device

```json
"qmaster": {
  "batch_size": 16,
  "num_workers": 4,
  "train_limit": 500,
  "val_limit": 50,
  "device": "cuda:0"
}
```

### Training Loop

```json
"qmaster": {
  "epochs": 30,
  "lr": 1e-5,
  "optimizer": "adamw",
  "criterion": "mse",
  "scheduler": "cosine",
  "warmup_epochs": 1,
  "weight_decay": 1e-4,
  "max_grad_norm": 1.0,
  "use_amp": true,
  "early_stopping_patience": 5
}
```

### Knowledge Distillation (KD)

KD uses the original floating-point model as a teacher to guide the quantized student. It is enabled by default and generally improves accuracy.

```json
"qmaster": {
  "use_kd": true,
  "kd_loss": "mse",
  "kd_alpha": 1.0,
  "kd_temperature": 4.0
}
```

!!! note "KD Loss Weighting"
    `kd_alpha` weights the KD term; the task loss is weighted by `1 - kd_alpha`.
    With the default `kd_alpha = 1.0` the model trains with **KD only**. Lower it
    (e.g. `0.7`) to blend KD with the task loss.

!!! note "Encoder Mode"
    For embedding/encoder-style models (e.g. CLIP image encoders), set
    `"encoder_mode": true`. This switches the tracked metric to **cosine similarity**
    (instead of classification accuracy). It does not disable the task loss on its own;
    keep `kd_alpha = 1.0` (the default) for pure KD training.

---

## Segmentation QAT (opt-in)

!!! note "Version Support"
    Segmentation QAT is supported in **DX-COM v2.5.0 and later**.

By default, QAT expects an ImageNet-style `(image, int_label)` classification
dataset. Set `"task_type": "segmentation"` to switch to a dense
`(image, mask)` segmentation dataset instead — every other `task_type`
(absent, or `"classification"`) is unaffected.

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

| Parameter | Default | Description |
|-----------|---------|-------------|
| `task_type` | `"classification"` | Set to `"segmentation"` to enable the dense segmentation loader/criterion. |
| `seg_root` | — | Root directory that `seg_pairs_train` / `seg_pairs_val` paths are relative to. |
| `seg_pairs_train` / `seg_pairs_val` | — | Pair-list text files; each line is `<image_path> <mask_path>`, relative to `seg_root`. |
| `seg_ignore_index` | `255` | Label value excluded from the loss/metric (e.g. unlabeled/void pixels). |
| `seg_binary` | `false` | Treat the task as binary (foreground/background) segmentation. |

When `task_type = "segmentation"`, `criterion` defaults to `"seg_ce"` (dense
cross-entropy over the mask) instead of `mse`/`cross_entropy`, unless you
override it explicitly. Masks are loaded as raw integer class-id maps and are
**not** run through the image `preprocessings` pipeline (only the image is).

---

## Control Parameters (Python API)

The following parameters control **training vs. compilation** behavior. They are available through the Python API (`dx_com.compile()`); the `dxcom` CLI runs the full QAT pipeline directly from the `qmaster` block.

!!! warning "Changed in v2.5.0"
    The former flat arguments `quantization_mode`, `qat_config`, `qat_skip_training`,
    and `qat_resume_from_checkpoint` have been **replaced by a single `qmaster`
    argument** that takes a `QMasterConfig` object. The old arguments are no longer
    honored from Python code. Triggering QAT from a JSON `qmaster` block is unchanged.

QAT from Python is controlled by one argument, `qmaster`, which takes a
`QMasterConfig` object (import it from the top-level `dx_com` package):

| `QMasterConfig` field | Type | Default | Description |
|-----------------------|------|---------|-------------|
| `config` | `Optional[dict]` | `None` | QAT training hyperparameters — the same keys as the JSON `qmaster` block (see [The `qmaster` Block](#the-qmaster-block) above). |
| `skip_training` | `bool` | `False` | Skip the training loop and run compilation only (Stage 2). Use with `resume_from_checkpoint`. |
| `resume_from_checkpoint` | `Optional[str]` | `None` | Path to a `qat_checkpoint.qxnn`. Loads trained weights, then compiles. |

!!! tip "Re-running Compilation Only"
    Training can take a long time. After a successful run you can regenerate the
    `.dxnn` without re-training by passing the saved checkpoint through `qmaster`:

    ```python
    qmaster=QMasterConfig(
        skip_training=True,
        resume_from_checkpoint="<path>.qxnn",
    )
    ```

!!! note "`fast_run` Is a Config Key"
    To run a quick smoke test, set `"fast_run": true` **inside the `qmaster` block**
    of the JSON config (it is not a `compile()` argument).

---

## Usage

### CLI (`dxcom`)

Add a `qmaster` block to your config and compile as usual — QAT runs automatically.

```bash
dxcom -m model.onnx -c config_with_qmaster.json -o output/
```

### Python API

```python
import dx_com
from dx_com import QMasterConfig

# Basic QAT (training + compilation). A qmaster block in the JSON config
# triggers QAT automatically — no extra argument required.
dx_com.compile(
    model="model.onnx",
    config="config_with_qmaster.json",
    output_dir="output/",
)

# Building the QAT config in code instead of JSON (New in v2.5.0).
dx_com.compile(
    model="model.onnx",
    output_dir="output/",
    config="config.json",
    qmaster=QMasterConfig(config={"epochs": 30, "lr": 1e-5, "use_kd": True}),
)

# Compilation only, reusing a previously trained checkpoint (New in v2.5.0).
# QAT config comes from the qmaster= argument, so the JSON needs no qmaster block.
dx_com.compile(
    model="model.onnx",
    config="config.json",
    output_dir="output/",
    qmaster=QMasterConfig(
        skip_training=True,
        resume_from_checkpoint="output/qat_checkpoint/qat_checkpoint.qxnn",
    ),
)
```

---

## Output Files

| File | Description |
|------|-------------|
| `<output_dir>/*.dxnn` | Compiled NPU binary (the deliverable). |
| `<output_dir>/qat_checkpoint/qat_checkpoint.qxnn` | Best training checkpoint, for `QMasterConfig(resume_from_checkpoint=...)`. |

---

## Notes and Recommendations

!!! warning "BatchNorm Freezing"
    `freeze_bn_after = 0` freezes BatchNorm from the very first epoch, which can cause
    the loss to diverge (`nan`). Leave it as `null` unless you specifically need BN
    freezing, and in that case start from a later epoch.

!!! warning "Dataset Path"
    If `default_loader.dataset_path` is missing or invalid, DX-COM falls back to a
    default ImageNet location instead of failing. Verify the dataset path in the log to
    make sure training used the data you intended.

!!! tip "Reducing GPU Memory"
    If you hit out-of-memory errors, lower `batch_size` and/or raise
    `gradient_accumulation_steps` to keep the effective batch size constant. Setting
    `"train_cpu_fp": true` moves the FP teacher to CPU to save GPU memory (slightly slower).

---

## Related Pages

- [JSON File Configuration](02_05_JSON_File_Configuration.md) — base config (`inputs`, `calibration_*`, `default_loader`).
- [Execution of DX-COM](02_06_Execution_of_DX-COM.md) — CLI and Python API reference.
- [Change Log](Appendix_Change_Log.md) — QAT was added in v2.4.0.
