# Q-Master (QAT) Reference

> Agent reference for Quantization-Aware Training in DX-COM (v2.5.0).
> User-facing manual: `source/docs/02_08_Quantization_Aware_Training.md`.
> **Q-Master** is DEEPX's product name for its QAT feature. Both terms refer to the same feature.

## When to Use — and When NOT to

**MUST** keep the default PTQ (EMA) flow unless the user **explicitly** asks for QAT / Q-Master.
**NEVER** add a `qmaster` block on your own initiative.

Suggest QAT (as an option, never silently) only when **all** of these hold:

1. The model already compiles with PTQ using the same JSON config.
2. The calibration method was tuned (`ema` → `minmax` → `iqr`) and accuracy is still below the user's target.
3. Q-PRO (`use_q_pro`) was tried or ruled out — see [Constraints](#constraints-and-conflicts).
4. A CUDA GPU and representative training images (hundreds to thousands) are available.

<!-- NOTE: no numeric accuracy-drop threshold for choosing QAT is defined in the manual or the v2.5.0 code. Ask the user for their accuracy target; do not invent one. -->

| | PTQ (default) | Q-Master (QAT) |
|---|---|---|
| Data | ~100 calibration images | hundreds–thousands of training images, **labels optional** |
| GPU | not required | **required** (CUDA, default `cuda:0`) |
| Time | minutes | minutes to hours |
| Weights | unchanged | fine-tuned |
| Command | `dxcom -m ... -c ... -o ...` | **same command**, JSON gains a `qmaster` block |

## How It Works

- The presence of a `qmaster` block in the JSON (or `qmaster=QMasterConfig(...)` in Python) switches the compile from PTQ to Q-Master. **No CLI flag exists or is needed.**
- `default_loader.preprocessings` is the **single** source for both calibration and training data. **NEVER** redefine preprocessing inside `qmaster`.
- Pipeline: calibration → Stage 1 training (at `batch_size`) → Stage 2 compile to `.dxnn` (always batch 1).
- Default loss is Knowledge Distillation from the FP32 model (`use_kd=true`, `kd_loss=mse`, `kd_alpha=1.0`), so **no labels are needed**.

## Minimal Config (JSON)

Append a `qmaster` block to the working PTQ JSON:

```json
{
  "inputs": { "input": [1, 3, 224, 224] },
  "calibration_num": 100,
  "calibration_method": "ema",
  "default_loader": {
    "dataset_path": "/path/to/train_images",
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
  "qmaster": { "batch_size": 16, "train_limit": 2000, "val_limit": 200, "epochs": 10 }
}
```

> **Inference**: `convertColor` is not integrated into the NPU graph (listed under
> `Skipped nodes` in `compiler.log`). The inference code must apply the same `BGR2RGB`
> conversion, or inference sees a different channel order from calibration/training and
> accuracy drops silently.

```bash
dxcom -m model.onnx -c config_with_qmaster.json -o output/
```

<!-- NOTE: the commands above were NOT executed in this session (no GPU run of v2.5.0). The JSON structure and key names follow the user manual (`02_08` Quick Start and Parameter Reference), not a live compile. -->

## Python API

```python
import dx_com
from dx_com import QMasterConfig

# JSON-driven (qmaster block in config.json)
dx_com.compile(model="model.onnx", config="config_with_qmaster.json", output_dir="output/")

# Hyperparameters in code (JSON needs no qmaster block)
dx_com.compile(
    model="model.onnx",
    config="config.json",
    output_dir="output/",
    qmaster=QMasterConfig(config={"epochs": 10, "batch_size": 16, "train_limit": 2000}),
)

# Compile only from a trained checkpoint
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

| `QMasterConfig` field | Type | Default | Description |
|---|---|---|---|
| `config` | `Optional[dict]` | `None` | Same keys as the JSON `qmaster` block |
| `skip_training` | `bool` | `False` | Skip training; compile from a checkpoint |
| `resume_from_checkpoint` | `Optional[str]` | `None` | Path to `qat_checkpoint.qxnn` |

- `fast_run` and `stage1_mode` are **JSON/config keys** inside `qmaster`, **not** `compile()` arguments.
- In Python use `skip_training` / `resume_from_checkpoint`; `stage1_mode` is read only from the JSON `qmaster` block.

### Removed in v2.5.0 (migration only)

`quantization_mode`, `qat_config`, `qat_skip_training`, `qat_resume_from_checkpoint` were replaced by `qmaster=`.

- **VERIFIED** (v2.5.0 wheel, live run): `quantization_mode` and `qat_skip_training` **raise `InvalidValueError`** ("are no longer accepted by compile(); pass QAT settings via qmaster=").
- **VERIFIED** (v2.5.0 wheel, live run): `qat_config` and `qat_resume_from_checkpoint` do **not** raise. They are silently ignored and the compile continues. Unknown keyword arguments (e.g. `no_such_option=1`) are ignored the same way. Their settings are NOT applied.

**NEVER** use these names in new code, examples, or generated configs.

## Hyperparameters

All keys optional. Defaults match the user manual (`02_08` Parameter Reference).

### Data and device

| Key | Type | Default | Recommended |
|---|---|---|---|
| `batch_size` | int | `1` | `16` (lower on OOM) |
| `num_workers` | int | `4` | keep |
| `train_limit` | int | `500` | `2000`+ for real runs (default is smoke-test scale) |
| `val_limit` | int | `50` | `200`+; taken **before** training images from the same pool |
| `train_drop_last` / `val_drop_last` | bool | `true` / `false` | keep |
| `device` | str | `"cuda:0"` | keep; pick GPU with `CUDA_VISIBLE_DEVICES` |
| `train_cpu_fp` | bool | `false` | `false` — `true` also trains CPU (non-NPU) subgraph weights |

### Training loop

| Key | Type | Default | Recommended |
|---|---|---|---|
| `epochs` | int | `30` | `10` for first run |
| `lr` | float | `1e-5` | `5e-6` if accuracy worsens from epoch 1 |
| `optimizer` | str | `"adamw"` | `"adamw"` or `"sgd"` |
| `weight_decay` | float | `1e-4` | keep |
| `scheduler` | str\|null | `null` | `null`, `"cosine"`, `"step"` |
| `scheduler_step_size` | int | `max(1,(epochs-warmup_epochs)//3)` | `"step"` only |
| `warmup_epochs` | int | `0` | keep |
| `max_grad_norm` | float | `1.0` | keep |
| `use_amp` | bool | `true` | keep |
| `gradient_accumulation_steps` | int | `1` | effective batch = `batch_size × this` |
| `early_stopping_patience` | int\|null | `5` | needs validation data; `null` disables |
| `early_stopping_delta` | float | `1e-3` | keep |
| `save_best_model` | bool | `true` | keep |
| `freeze_bn_after` | int\|null | `null` | **NEVER** `0` (can produce `nan`); leave `null` |

### Loss and KD

Loss = `kd_alpha × KD + (1 − kd_alpha) × task`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `use_kd` | bool | `true` | FP teacher |
| `kd_loss` | str | `"mse"` | `mse`, `kl_div`, `cosine`, `bce`, `smooth_l1`, `ciou`, `giou` |
| `kd_alpha` | float | `1.0` | at `1.0` the task loss is **not computed** |
| `kd_temperature` | float | `4.0` | `kl_div` / `bce` only |
| `kd_box_format` | str | `"xyxy"` | `ciou`/`giou` only: `xyxy`, `cxcywh`, `xywh` |
| `criterion` | str | `"mse"` | `mse`, `cross_entropy` (`seg_ce` for segmentation); used only if `kd_alpha<1` or `use_kd=false`. `cross_entropy` switches to the labeled ImageFolder loader |
| `label_smoothing` | float | `0.0` | cross-entropy only |

| Goal | Settings |
|---|---|
| No labels (default) | defaults |
| Classification with labels | `criterion="cross_entropy"`, `kd_loss="kl_div"`, `kd_temperature=2.0`, `kd_alpha=0.5` |
| No teacher | `use_kd=false` + a `criterion` |
| Embedding / encoder model | `encoder_mode=true`, `kd_alpha=1.0` |
| Zero-shot (CLIP) | `zeroshot_weights_path="<.npy>"`, `use_kd=false` |

**MUST**: zero-shot cannot be combined with `use_kd` or `encoder_mode` (v2.5.0 raises an error).

### Mode switches

| Key | Type | Default | Notes |
|---|---|---|---|
| `encoder_mode` | bool | `false` | tracks cosine similarity instead of accuracy |
| `zeroshot_weights_path` | str | — | `.npy` text embeddings |
| `stage1_mode` | str | `"fresh"` | `fresh` / `resume` / `skip` (see [Artifacts](#artifacts-and-resume)) |
| `fast_run` | bool | `false` | 1 epoch × 1 batch, 100 train / 10 val images; **not accuracy-meaningful** |

## Segmentation

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

| Key | Default | Notes |
|---|---|---|
| `task_type` | `"classification"` | set `"segmentation"` for `(image, mask)` data |
| `seg_root` | — | root for pair lists |
| `seg_pairs_train` / `seg_pairs_val` | — | text files, one `<image_path> <mask_path>` per line, relative to `seg_root` |
| `seg_ignore_index` | `255` | label excluded from loss and metric |
| `seg_binary` | `true` | **`false` for multi-class** (default is binary) |

- `criterion` defaults to `seg_ce` for segmentation. Masks bypass `preprocessings`; only the image goes through it.
- Segmentation Q-Master requires v2.5.0+.

<!-- NOTE: segmentation example above is NOT verified by a live run. It is the user manual's example (`02_08` E. Segmentation); the segmentation keys and defaults in the table above match its Segmentation Parameters table. -->

## Data Requirements

| Item | Rule |
|---|---|
| Image count | `train_limit + val_limit` images; if fewer exist, all are used. Default recipe: 2000 + 200 |
| Labels | **Not required** for default KD. Required only with `criterion="cross_entropy"` (ImageFolder: `<dataset_path>/<class>/<image>`) |
| Calibration images | May be reused, but varied images give better results. **NEVER** train on the set used to report final accuracy |
| Preprocessing | Same as PTQ (`default_loader.preprocessings`) |

**MUST** warn the user:

- With `cross_entropy`, class indices come from class folders present in the **loaded subset**. A missing class shifts all labels. Ensure every class is present or use the default (no-label) recipe.
- If `default_loader.dataset_path` is missing/invalid, v2.5.0 **silently falls back** to a built-in ImageNet location. **ALWAYS** verify `dataset_path` exists before compiling.

## Resources and Time

- **GPU required.** Check first: `python -c "import torch; print(torch.cuda.is_available())"` must print `True`. **NEVER** start QAT without a GPU; tell the user instead.
- **ALWAYS** run a `fast_run` smoke test (`"fast_run": true`) before a long run; remove it for the real run.
- On CUDA OOM, lower `batch_size` and raise `gradient_accumulation_steps` (e.g. `4` × `4`). v2.5.0 auto-retries Stage 1 at `batch_size=1`, which works but is **much slower**.
- Duration scales with `epochs × train_limit` and model size.
<!-- NOTE: no per-model-size time estimates are verified. Do not quote numbers; tell the user to time the fast_run and extrapolate. -->
- Agent sessions have time limits: run long jobs in the background with the `compile.pid` + `subprocess.Popen` pattern in `.deepx/agents/dx-dxnn-compiler.md` (check liveness with `kill -0`; **NEVER** sleep-poll or use `pgrep -f`). Check the **Q-MASTER CONFIG** box in `compiler.log` once right after launch.

## Artifacts and Resume

| Path | Description |
|---|---|
| `<output_dir>/<model>.dxnn` | Final NPU binary |
| `<output_dir>/qat_checkpoint/qat_checkpoint.qxnn` | Best checkpoint (lowest **validation loss**, includes KD term; may differ from best Top-1) |
| `<output_dir>/compiler.log` | Starts with a **Q-MASTER CONFIG** box listing values actually applied |

`stage1_mode` (JSON `qmaster` block only):

| Value | Behavior | Use when |
|---|---|---|
| `fresh` (default) | Train from scratch, overwrite checkpoint | first run |
| `resume` | Load checkpoint weights and continue (optimizer/epoch restart); trains from scratch with a warning if none exists | continue with lower `lr` |
| `skip` | Skip training, run Stage 2 only; checkpoint **must** exist or an error is raised | rebuild `.dxnn` |

- An invalid `stage1_mode` raises `ValueError`.
- To use an external checkpoint, copy it to `<output_dir>/qat_checkpoint/qat_checkpoint.qxnn` first.
- The `.qxnn` from `quant_diagnosis` is **not** interchangeable with `qat_checkpoint.qxnn`.
- **ALWAYS** read the **Q-MASTER CONFIG** box in `compiler.log` after launch: unknown/misspelled `qmaster` keys are **silently ignored** (e.g. `learning_rate` instead of `lr`).

## Success Criteria

- **MUST** compare against the PTQ result on the **same** evaluation set and preprocessing. QAT does not guarantee a gain; report the numbers either way.
- A compile that finishes and produces a `.dxnn` is necessary but **not sufficient**; accuracy is the criterion.
- `verify.py` checks structural/runtime validity of the `.dxnn`; it does not measure task accuracy.
<!-- NOTE: whether the verify.py PASS threshold should differ for QAT outputs was NOT verified. Do not change thresholds; report accuracy separately. -->
- If training metrics look good but the `.dxnn` accuracy dropped, a compiler stage after training is the likely cause. Compare the `.dxnn` against the original model on the same evaluation set and report the gap to DEEPX.
- **NEVER** suggest `--optimize_check`: the v2.5.0 `dxcom` CLI does not have it (`dxcom: error: unrecognized arguments: --optimize_check`, exit 2; same for `--optimize_check_num_samples`).

## Constraints and Conflicts

| Combination | Status in v2.5.0 |
|---|---|
| `qmaster` + `use_q_pro` / `enhanced_scheme` | **Mutually exclusive.** Compile raises `EnhancementSchemeError`: "use_q_pro/enhanced_scheme (Q-PRO re-quantization) and qmaster (QAT) are mutually exclusive. Set only one." **VERIFIED** on v2.5.0: `dxcom` exits 1 and `dx_com.compile()` raises this error. **NEVER** set both |
| `qmaster` + `use_kd` + zero-shot | Raises an error. Use `use_kd=false` |
| `qmaster` + `encoder_mode` + zero-shot | Not allowed |
| `qmaster` + `ppu` / `pre_optimize` | <!-- NOTE: NOT verified. Do not combine unless the user insists; if so, run fast_run first and report the result. --> unverified |
| Multi-input models | <!-- NOTE: NOT verified for QAT. Ask the user; run fast_run first. --> unverified |
| Supported tasks | classification (default), embedding/encoder, zero-shot, segmentation (v2.5.0+) |

Q-Master is available from DX-COM v2.4.0; the `qmaster=` Python API and segmentation from v2.5.0.

## Common Errors

| Symptom / message | Cause | Fix |
|---|---|---|
| `InvalidValueError: quantization_mode, qat_skip_training are no longer accepted by compile(); pass QAT settings via qmaster=` | Pre-v2.5.0 flat arguments used | Use `qmaster=QMasterConfig(...)` |
| `EnhancementSchemeError: use_q_pro/enhanced_scheme (Q-PRO re-quantization) and qmaster (QAT) are mutually exclusive. Set only one.` | Both enabled | Remove `use_q_pro`/`enhanced_scheme`, or remove `qmaster` |
| `FileNotFoundError: The QAT staged compilation setup is invalid or incomplete. Provide compatible QAT inputs and required training artifacts, then retry.` | `stage1_mode="skip"` but no `qat_checkpoint.qxnn` in `output_dir` | Use `fresh`, or copy a checkpoint to `<output_dir>/qat_checkpoint/` |
| `ValueError: Invalid stage1_mode 'bogus'. Must be one of ('fresh', 'resume', 'skip').` | Value not in `fresh`/`resume`/`skip` | Fix the value |
| `ValueError: Q-Master dispatch could not determine training batch size. Set qat_config['batch_size'] explicitly, ...` | `QMasterConfig(config=...)` without `batch_size` | Always set `batch_size` in the Python API |
| CUDA out of memory | `batch_size` too large | Lower `batch_size`, raise `gradient_accumulation_steps` |
| Loss becomes `nan` | `freeze_bn_after=0` or `lr` too high | `freeze_bn_after=null` or a later epoch; lower `lr` |
| Best epoch is epoch 1, later epochs worse | `lr` too high | Lower `lr`; `stage1_mode="resume"` with smaller `lr` |
| Training stops very early | `early_stopping_patience` too small / noisy val | Raise patience and `val_limit` |
| Accuracy not better than PTQ | Too little data / loss mismatch | Raise `train_limit`; use labeled recipe if labels exist |
| Settings have no effect | Misspelled key or wrong block | Check the Q-MASTER CONFIG box in `compiler.log` |
| Training used unexpected data | Invalid `dataset_path` → silent fallback | Fix the path; check `compiler.log` |
| Zero-shot + `use_kd` error | Unsupported combination | `use_kd=false` |

<!-- NOTE: only messages found in v2.5.0 source are quoted verbatim. Messages not listed here were NOT verified. -->

## Agent Checklist

Before launching QAT, **ALL** must be true:

- [ ] User explicitly requested QAT / Q-Master (or accepted your suggestion).
- [ ] PTQ compile of the same model/config already succeeded.
- [ ] `torch.cuda.is_available()` is `True`.
- [ ] `default_loader.dataset_path` exists and holds representative images.
- [ ] No `use_q_pro` / `enhanced_scheme` in the config.
- [ ] A `fast_run` smoke test passed.
- [ ] After launch, the Q-MASTER CONFIG box in `compiler.log` matches intent.
- [ ] Final report compares QAT vs PTQ accuracy on the same eval set.

## Related

- `.deepx/toolsets/config-schema.md` — `qmaster` key in the JSON schema
- `.deepx/toolsets/dxcom-api.md` — `QMasterConfig` in `dx_com.compile()`
- `.deepx/instructions/compilation-workflow.md` — accuracy-improvement order (PTQ → Q-PRO → QAT)
- `.deepx/memory/common_pitfalls.md` — QAT pitfall
