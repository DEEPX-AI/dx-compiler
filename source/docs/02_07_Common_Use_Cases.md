# Common Use Cases

This chapter provides practical, real-world scenarios with ready-to-use examples. Each use case demonstrates the implementation using both CLI and Python API where applicable. 

---

## Use Case 1: Simple Image Classification (ResNet / MobileNet)

**Scenario**: Compiling a pre-trained ResNet50 or MobileNetV1 model using standard image preprocessing.  

- **Option A: CLI Method** – Best for quick, standard builds.  
- **Option B: Python API Method** – Best for integration into automated scripts.  

### Option A: CLI Method

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
./dx_com/dx_com \
  -m ResNet50_sim.onnx \
  -c resnet50_config.json \
  -o output/resnet50 \
  --opt_level 1
```

### Option B: Python API Method

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

!!! note "Python API Only"
    Multi-input models are **only supported via Python API**. CLI does not support multiple inputs.

### Python API Method

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
        self.left_dir = left_dir
        self.right_dir = right_dir
        
        # Get matching image pairs
        self.image_files = sorted([
            f for f in os.listdir(left_dir) 
            if f.endswith(('.jpg', '.png'))
        ])
        
        # Different preprocessing for each input
        self.transform_left = transforms.Compose([
            transforms.Resize((128, 128)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])
        
        self.transform_right = transforms.Compose([
            transforms.Resize((256, 256)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])
    
    def __len__(self):
        return len(self.image_files)
    
    def __getitem__(self, idx):
        filename = self.image_files[idx]
        
        # Load left image
        left_img = Image.open(
            os.path.join(self.left_dir, filename)
        ).convert('RGB')
        left_tensor = self.transform_left(left_img)
        
        # Load right image
        right_img = Image.open(
            os.path.join(self.right_dir, filename)
        ).convert('RGB')
        right_tensor = self.transform_right(right_img)
        
        # Return tuple of inputs (order must match model)
        return left_tensor, right_tensor

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

- **DataLoader Output:** The DataLoader must return a tuple of tensors (one per input).  
- **Input Mapping:** The order of tensors in the tuple must align strictly with the ONNX model’s input node order.  
- **Heterogeneous Inputs:** Each input branch supports independent sizes and preprocessing configurations.  

---

## Use Case 3: Performance Optimization for Edge Devices

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

You can compile using either **CLI** or **Python API**. Choose one:  

### Option A: CLI Method

```bash
./dx_com/dx_com \
  -m efficient_model.onnx \
  -c config.json \
  -o output/efficient \
  --aggressive_partitioning \
  --opt_level 0
```

### Option B: Python API Method

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

!!! note "Python API Only"
    Non-image data types are **only supported via Python API**. CLI only supports image data.

### Python API Method

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

## Use Case 5: GPU-Accelerated Quantization

**Scenario**: Reducing compilation time for large-scale models or when utilizing compute-intensive quantization algorithms (DXQ-P3, P4, or P5).  

!!! note "Python API Only"
    GPU-accelerated quantization (`quantization_device="cuda"`) is **only available via Python API**. CLI always uses CPU.

### Basic GPU Quantization

```python
import dx_com

dx_com.compile(
    model="large_model.onnx",
    output_dir="output/large_model",
    config="config.json",
    quantization_device="cuda:0",  # Use GPU 0
    opt_level=1,
    calibration_num=100
)
```

### GPU with Enhanced Quantization (DXQ)

DXQ (`enhanced_scheme`) is supported in **DX-COM v2.1.0 and later**.

For improved accuracy with GPU acceleration:

```python
import dx_com

dx_com.compile(
    model="large_model.onnx",
    output_dir="output/large_model_dxq",
    config="config.json",
    quantization_device="cuda:0",  # GPU acceleration
    enhanced_scheme={
        "DXQ-P3": {"num_samples": 1024}
    },
    opt_level=1,
    calibration_num=100
)
```

**Hardware Requirements**:  

- GPU: NVIDIA GPU with CUDA support  
- LibraryPyTorch built with CUDA support  
- Verification: `python -c "import torch; print(torch.cuda.is_available())"`  

**Quantization Speedup**: 2x – 5x faster compared to CPU-only execution.    

---
