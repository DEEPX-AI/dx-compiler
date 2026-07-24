# Common Use Cases

This chapter provides practical, real-world scenarios with ready-to-use examples. Each use case demonstrates the implementation using the `dxcom` command and the `dx_com` Python module where applicable. 

!!! note "Additional Dependencies"
    Some examples in this chapter use `torchvision` for image preprocessing. Install it before running these examples:
    ```bash
    pip install torchvision
    ```

---

## Use Case 1: Simple Image Classification (ResNet / MobileNet)

**Scenario**: Compiling a pre-trained ResNet50 or MobileNetV1 model using standard image preprocessing.  

- **Option A: `dxcom` Command** – Best for quick, standard builds.  
- **Option B: `dx_com` Python Module** – Best for integration into automated scripts.  

### Option A: `dxcom` Command

**Configuration File** (`resnet50_config.json`):
```json
{
  "inputs": {
    "input": [1, 3, 224, 224]
  },
  "calibration_method": "ema",
  "calibration_num": 100,
  "default_loader": {
    "dataset_path": "./calibration_images",
    "file_extensions": ["jpeg", "jpg", "png"],
    "preprocessings": [
      {"resize": {"mode": "torchvision", "size": 256, "interpolation": "BILINEAR"}},
      {"centercrop": {"width": 224, "height": 224}},
      {"convertColor": {"form": "BGR2RGB"}},
      {"div": {"x": 255}},
      {"normalize": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}}
    ]
  }
}
```

**Command**:
```bash
dxcom \
  -m ResNet50_sim.onnx \
  -c resnet50_config.json \
  -o output/resnet50 \
  --opt_level 1
```

### Option B: `dx_com` Python Module

**Complete Script** (`compile_resnet50.py`):
```python
import dx_com
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import os

class ImageNetDataset(Dataset):
    """Standard ImageNet-style dataset"""
    def __init__(self, image_dir, img_size=224):
        self.image_dir = image_dir
        self.image_files = sorted([
            f for f in os.listdir(image_dir) 
            if f.endswith(('.jpg', '.png', '.jpeg'))
        ])
        self.transform = transforms.Compose([
            transforms.Resize((img_size, img_size)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])
    
    def __len__(self):
        return len(self.image_files)
    
    def __getitem__(self, idx):
        img_path = os.path.join(self.image_dir, self.image_files[idx])
        image = Image.open(img_path).convert('RGB')
        return self.transform(image)

# Setup
dataset = ImageNetDataset('./calibration_images', img_size=224)
dataloader = DataLoader(dataset, batch_size=1, shuffle=True)

# Compile
dx_com.compile(
    model="ResNet50_sim.onnx",
    output_dir="output/resnet50",
    dataloader=dataloader,
    calibration_method="ema",
    calibration_num=100,
    opt_level=1
)

print("ResNet50 compilation complete!")
```

**Run**:
```bash
python3 compile_resnet50.py
```

---

## Use Case 2: Multi-Input Models (Stereo Vision)

**Scenario**: A stereo camera system requiring two image inputs with different dimensions.  

!!! note "dx_com Python Module Only"
    Multi-input models are **only supported via the `dx_com` Python module**. The `dxcom` command does not support multiple inputs.

### `dx_com` Python Module

```python
import dx_com
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import os

class StereoDataset(Dataset):
    """Dataset providing stereo image pairs"""
    def __init__(self, left_dir, right_dir):
        self.dirs = {"left_input": left_dir, "right_input": right_dir}
        
        # Get matching image pairs
        self.image_files = sorted([
            f for f in os.listdir(left_dir) 
            if f.endswith(('.jpg', '.png'))
        ])
        
        # Per-input preprocessing, keyed by ONNX input node name.
        # Keys MUST match the model's input node names exactly.
        self.transform = {
            "left_input": transforms.Compose([
                transforms.Resize((128, 128)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225]
                )
            ]),
            "right_input": transforms.Compose([
                transforms.Resize((256, 256)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225]
                )
            ]),
        }
    
    def __len__(self):
        return len(self.image_files)
    
    def __getitem__(self, idx):
        filename = self.image_files[idx]
        
        # Build a dict keyed by ONNX input node names.
        sample = {}
        for input_name, dir_path in self.dirs.items():
            image = Image.open(
                os.path.join(dir_path, filename)
            ).convert('RGB')
            sample[input_name] = self.transform[input_name](image)
        return sample

# Setup
dataset = StereoDataset(
    left_dir='./calibration_left',
    right_dir='./calibration_right'
)
dataloader = DataLoader(dataset, batch_size=1)

# Compile multi-input model
dx_com.compile(
    model="stereo_model.onnx",
    output_dir="output/stereo",
    dataloader=dataloader,
    calibration_method="ema",
    calibration_num=50,  # Fewer samples needed for smaller models
    opt_level=1
)

print("Stereo model compilation complete!")
```

**Key Technical Requirements**:  

- **DataLoader Output:** For multi-input models, return a **`dict[str, torch.Tensor]`** keyed by the ONNX input node names. The calibrator maps a dict by **name** (`run_session` matches each key to a model input), so the keys must match the input node names exactly.  
- **Why dict (not tuple):** A tuple/list is also accepted, but it is mapped to inputs **by position** in the model's internal input-node order — not the order you return them. A name-keyed dict removes this ambiguity and is the recommended form for multi-input models.  
- **Shape & dtype:** Each per-input tensor must match its ONNX input shape without the batch dim, and `batch_size` must equal the model's input batch (normally `1`). Tensors should be `float32`. See [Defining Preprocessing Transforms in the DataLoader](02_06_Execution_of_DX-COM.md#defining-preprocessing-transforms-in-the-dataloader).  
- **Heterogeneous Inputs:** Each input branch supports independent sizes and preprocessing configurations.  

---

## Use Case 3: Performance Optimization for Edge Devices

!!! warning "Experimental Feature"
    `aggressive_partitioning` is currently experimental and may produce unexpected results for some models.

**Scenario**: Deploying on embedded systems with restricted CPU resources. The goal is to maximize NPU offloading while maintaining short compilation times.  

### Configuration for Aggressive Partitioning

```json
{
  "inputs": {
    "input": [1, 3, 224, 224]
  },
  "calibration_method": "ema",
  "calibration_num": 50,
  "default_loader": {
    "dataset_path": "./calibration_images",
    "file_extensions": ["jpeg", "jpg", "png"],
    "preprocessings": [
      {"resize": {"width": 224, "height": 224}},
      {"normalize": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}}
    ]
  }
}
```

You can compile using either the **`dxcom` command** or the **`dx_com` Python module**. Choose one:  

### Option A: `dxcom` Command

```bash
dxcom \
  -m efficient_model.onnx \
  -c config.json \
  -o output/efficient \
  --aggressive_partitioning \
  --opt_level 0
```

### Option B: `dx_com` Python Module

```python
import dx_com

# Maximize NPU offloading with aggressive partitioning
dx_com.compile(
    model="efficient_model.onnx",
    output_dir="output/efficient",
    config="config.json",
    aggressive_partitioning=True,  # Maximize NPU usage
    calibration_num=50  # Fewer samples = faster calibration
)
```

**Optimization Strategy: Aggressive Partitioning**:  

-  **Pros**: Maximum NPU offloading, significantly reduced host CPU load and faster compilation cycles.  
- **Cons**: Potential for slightly higher latency compared to `opt_level 1` and increased output binary size.  

---

## Use Case 4: Custom Data Type (Non-Image)

**Scenario**: Processing non-visual data such as audio spectrograms, time-series data, or 3D point clouds.  

!!! note "dx_com Python Module Only"
    Non-image data types are **only supported via the `dx_com` Python module**. The `dxcom` command only supports image data.

### `dx_com` Python Module

```python
import dx_com
import torch
from torch.utils.data import Dataset, DataLoader
import numpy as np
import os

class CustomDataDataset(Dataset):
    """Example: Audio spectrogram dataset"""
    def __init__(self, data_dir, input_shape=(1, 64, 128)):
        self.data_files = sorted([
            f for f in os.listdir(data_dir) 
            if f.endswith('.npy')
        ])
        self.data_dir = data_dir
        self.input_shape = input_shape
    
    def __len__(self):
        return len(self.data_files)
    
    def __getitem__(self, idx):
        # Load numpy array (e.g., audio spectrogram)
        data = np.load(os.path.join(self.data_dir, self.data_files[idx]))
        
        # Normalize to [0, 1]
        data = (data - data.min()) / (data.max() - data.min() + 1e-8)
        
        # Convert to tensor with correct shape
        return torch.from_numpy(data.astype(np.float32)).unsqueeze(0)

# Setup
dataset = CustomDataDataset('./spectrogram_data', input_shape=(1, 64, 128))
dataloader = DataLoader(dataset, batch_size=1)

# Compile
dx_com.compile(
    model="audio_model.onnx",
    output_dir="output/audio_model",
    dataloader=dataloader,
    calibration_method="minmax",  # minmax better for non-image data
    calibration_num=100,
)
```

---

## Use Case 5: Enhanced Quantization (DXQ)

**Scenario**: Improving quantization accuracy for models where standard quantization causes unacceptable accuracy degradation.  

!!! note "Version Support"
    DXQ (`enhanced_scheme`) is supported in **DX-COM v2.1.0 and later**.

- **Option A: `dxcom` Command** – Set `enhanced_scheme` in the JSON config file.  
- **Option B: `dx_com` Python Module** – Pass `enhanced_scheme` as a parameter directly.  

### Option A: `dxcom` Command

**Configuration File** (`config.json`):
```json
{
  "inputs": {
    "input": [1, 3, 224, 224]
  },
  "calibration_method": "ema",
  "calibration_num": 100,
  "enhanced_scheme": {
    "DXQ-P3": {"num_samples": 1024}
  },
  "default_loader": {
    "dataset_path": "./calibration_images",
    "file_extensions": ["jpeg", "jpg", "png"],
    "preprocessings": [
      {"resize": {"width": 224, "height": 224}},
      {"normalize": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}}
    ]
  }
}
```

**Command**:
```bash
dxcom \
  -m large_model.onnx \
  -c config.json \
  -o output/large_model_dxq \
  --opt_level 1
```

### Option B: `dx_com` Python Module

```python
import dx_com

dx_com.compile(
    model="large_model.onnx",
    output_dir="output/large_model_dxq",
    config="config.json",
    enhanced_scheme={
        "DXQ-P3": {"num_samples": 1024}
    },
    opt_level=1,
    calibration_num=100
)
```

!!! note "GPU Device Selection"
    By default, DX-COM automatically uses GPU if available. In multi-GPU environments, you can specify a device via `quantization_device` in the JSON config or the `dx_com.compile()` parameter (e.g., `"cuda:1"`). See [Quantization Device](02_05_JSON_File_Configuration.md#optional-parameters-quantization-device) for details.

For all available DXQ schemes (DXQ-P0 to DXQ-P5) and their parameters, see [Enhanced Quantization Scheme (DXQ)](02_05_JSON_File_Configuration.md#optional-parameters-enhanced-quantization-scheme-dxq).

### Automatic Q-PRO (`use_q_pro`)

If you don't want to hand-pick a DXQ scheme, let DX-COM choose for you. Setting `use_q_pro` enables the **automatic Q-PRO pipeline**: the compiler generates DXQ combinations and applies the optimal quantization enhancement stages based on model structure and compile-time metrics — no manual `enhanced_scheme` tuning required.

!!! note "Version Support"
    Automatic Q-PRO (`use_q_pro`) is available in **DX-COM v2.4.0 and later**. It is **mutually exclusive** with manual `enhanced_scheme`.

**Option A: `dxcom` Command**
```bash
dxcom \
  -m large_model.onnx \
  -c config.json \
  -o output/large_model_qpro \
  --use_q_pro \
  --opt_level 1
```

**Option B: `dx_com` Python Module**
```python
import dx_com

dx_com.compile(
    model="large_model.onnx",
    output_dir="output/large_model_qpro",
    config="config.json",
    use_q_pro=True,   # automatic DXQ selection (do not combine with enhanced_scheme)
    opt_level=1,
    calibration_num=100,
)
```

!!! tip "Automatic vs Manual"
    Start with `use_q_pro=True` for the easiest path to higher-accuracy quantization. Switch to a manual `enhanced_scheme` (e.g., `{"DXQ-P3": {...}}`) only when you need precise control over a specific DXQ scheme. See [Automatic Q-PRO (`use_q_pro`)](02_06_Execution_of_DX-COM.md#automatic-q-pro-use_q_pro).

---

## Use Case 6: Diagnose and Re-quantize Without Recompile

**Scenario**: A model compiled successfully, but quantization accuracy is lower than expected. You want to (1) find out *which* regions are responsible and (2) iterate on quantization settings **without paying the full compile cost each time**.

This use case chains three v2.4.0 features into one tuning loop:

1. **`quant_diagnosis`** — produces an HTML report of per-region quantization quality **plus** a reusable `.qxnn` checkpoint.
2. **QXNN Resume** — re-runs quantization from that `.qxnn` checkpoint, skipping the earlier compile phases.
3. **Re-calibration / Q-PRO** — applies a different calibration method or enables Q-PRO during the resume to improve accuracy.

!!! note "Version Support"
    `quant_diagnosis` and QXNN Resume are available in **DX-COM v2.4.0 and later**. For the full workflow reference, see [Quantization Tuning Workflow](02_07_Quantization_Tuning_Workflow.md).

### Step 1 — Compile with diagnosis enabled

Enabling `quant_diagnosis` writes both the HTML report and the `.qxnn` resume artifact under `quant_diagnosis/` in the output directory.

**Option A: `dxcom` Command**
```bash
dxcom \
  -m large_model.onnx \
  -c config.json \
  -o output/large_model \
  --quant_diagnosis
```

**Option B: `dx_com` Python Module**
```python
import dx_com

dx_com.compile(
    model="large_model.onnx",
    output_dir="output/large_model",
    config="config.json",
    quant_diagnosis=True,
)
```

This produces:

- `output/large_model/quant_diagnosis/large_model.qxnn` — resume checkpoint
- `output/large_model/quant_diagnosis/diagnosis_report.html` — per-region report with ready-to-paste retry snippets

Open the HTML report to identify high-severity regions and the recommended settings.

### Step 2 — Resume from the checkpoint with new settings

Instead of recompiling from the ONNX model, point `dxcom`/`dx_com` at the `.qxnn` checkpoint. The earlier compile phases are skipped and only quantization re-runs.

**Re-calibrate with a different observer:**
```bash
dxcom \
  --checkpoint output/large_model/quant_diagnosis/large_model.qxnn \
  -o output/large_model_iqr \
  --recalibration_method iqr
```

**Or enable automatic Q-PRO during the resume:**
```bash
dxcom \
  --checkpoint output/large_model/quant_diagnosis/large_model.qxnn \
  -o output/large_model_qpro \
  --use_q_pro
```

**Python equivalent:**
```python
import dx_com

# Re-quantize from the checkpoint — no recompile, no model/config needed
dx_com.compile(
    checkpoint="output/large_model/quant_diagnosis/large_model.qxnn",
    output_dir="output/large_model_iqr",
    recalibration_method="iqr",   # or: use_q_pro=True
)
```

!!! note "Resume-only options"
    `--recalibration_method`, `--enhanced_scheme`, and `--dataset_path` are valid **only** in QXNN resume mode (i.e., with `--checkpoint`). `--checkpoint` and `-m/--model_path` are mutually exclusive. On resume, the calibration DataLoader is auto-built from the config embedded in the `.qxnn` — no `-c/--config_path` is required.

!!! tip "Why this matters"
    Because QXNN Resume skips the compile phases that don't depend on quantization, you can try several calibration methods or Q-PRO settings in quick succession, dramatically shortening the accuracy-tuning loop.

---

## Use Case 7: YOLO Post-Processing Optimization (CPU-Constrained Edge)

**Scenario**: Deploying a YOLO-family detection or instance-segmentation model on a CPU-constrained edge host (for example, an ARM Cortex-A53) where CPU-side post-processing (Sigmoid, DFL decoding, dist2bbox over the full anchor grid) becomes the end-to-end throughput bottleneck.

**Approach**: Apply `dx_com.pre_optimize()` before `dx_com.compile()`. The API rewrites the post-processing graph so that TopK selection happens first, and expensive operations are applied only to the `K` selected candidates (default 300) instead of the full anchor grid.

```python
import onnx
import dx_com

model = onnx.load("yolov8n.onnx")
optimized = dx_com.pre_optimize(model, passes={
    "yolo_postprocess": {
        "layers": [
            {
                "bbox": "/model.22/cv2.0/cv2.0.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.0/cv3.0.2/Conv_output_0",
            },
            {
                "bbox": "/model.22/cv2.1/cv2.1.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.1/cv3.1.2/Conv_output_0",
            },
            {
                "bbox": "/model.22/cv2.2/cv2.2.2/Conv_output_0",
                "cls_conf": "/model.22/cv3.2/cv3.2.2/Conv_output_0",
            },
        ],
        "num_classes": 80,
        "topk": 300,
        "input_height": 640,
        "input_width": 640,
    },
})

dx_com.compile(
    model=optimized,
    config="yolov8n.json",
    output_dir="./yolov8n_optimized",
)
```

For supported model families (YOLOv8 / YOLOv9 / YOLOv11 / YOLOv12 / YOLOv13 via the `yolo_postprocess` pass, and YOLOv10 / YOLO26 via the `yolo26_postprocess` pass), output shapes, instance-segmentation usage, and the migration recipe from the deprecated `ppu.type = 2`, see [Pre-Optimize API](02_09_Pre_Optimize_API.md).

---

## Use Case 8: PPU Hardware Acceleration (YOLO)

**Scenario**: Offloading object-detection post-processing (confidence filtering, class prediction) to the on-NPU Post-Processing Unit for YOLO-family models, reducing host CPU load.

- **Option A: `dxcom` Command** – Set the `ppu` block in the JSON config file.
- **Option B: `dx_com` Python Module** – Pass a `PPUConfig` object via `ppu_config`.

Both paths configure the same hardware; the Python `PPUConfig` is the programmatic equivalent of the JSON `ppu` section. For node-name identification and the full parameter reference, see [PPU Configuration](02_05_JSON_File_Configuration.md#optional-parameters-ppu-configuration).

!!! warning "NMS still runs on the host CPU"
    The PPU accelerates filtering and class prediction only. Non-Maximum Suppression (NMS) must still be executed on the host CPU using the filtered outputs.

### Option A: `dxcom` Command

**Configuration File** (`yolov8_config.json`):
```json
{
  "inputs": {
    "images": [1, 3, 640, 640]
  },
  "calibration_method": "ema",
  "calibration_num": 100,
  "default_loader": {
    "dataset_path": "./calibration_images",
    "file_extensions": ["jpeg", "jpg", "png"],
    "preprocessings": [
      {"convertColor": {"form": "BGR2RGB"}},
      {"resize": {"width": 640, "height": 640}},
      {"div": {"x": 255}}
    ]
  },
  "ppu": {
    "type": 1,
    "conf_thres": 0.25,
    "num_classes": 80,
    "layer": [
      {"bbox": "Mul_441", "cls_conf": "Sigmoid_442"}
    ]
  }
}
```

```bash
dxcom -m yolov8.onnx -c yolov8_config.json -o output/yolov8
```

### Option B: `dx_com` Python Module

```python
import dx_com
from dx_com import PPUConfig, PPUTypes

# Anchor-free YOLOv8: build the PPU configuration
ppu_config = (
    PPUConfig()
    .set_type(PPUTypes.YOLO_ANCHORFREE)
    .set_num_classes(80)
    .set_conf_thres(0.25)
)
ppu_config.add_layer(bbox="Mul_441", cls_conf="Sigmoid_442")

dx_com.compile(
    model="yolov8.onnx",
    output_dir="output/yolov8",
    config="yolov8_config.json",  # or dataloader=...
    ppu_config=ppu_config,
)

print("YOLOv8 PPU-accelerated compilation complete!")
```

**Anchor-based (YOLOv5/v7) example** — type 0 uses a dict-style `layer` with `num_anchors` and requires `activation`:

```python
from dx_com import PPUConfig, PPUTypes

ppu_config = PPUConfig(
    type=PPUTypes.YOLO_BASE,
    conf_thres=0.25,
    activation="Sigmoid",
    num_classes=80,
    layer={
        "Conv_245": {"num_anchors": 3},
        "Conv_294": {"num_anchors": 3},
        "Conv_343": {"num_anchors": 3},
    },
)
```

!!! note "Selecting the PPU type"
    Match the `PPUTypes` value to your model architecture (anchor-based → `YOLO_BASE`, anchor-free → `YOLO_ANCHORFREE`, DFL-based CPU TopK → `YOLOV8`). See the [type/model table](02_05_JSON_File_Configuration.md#configuration-parameters) and the [PPUConfig API reference](02_06_Execution_of_DX-COM.md#optional-parameters).

---
