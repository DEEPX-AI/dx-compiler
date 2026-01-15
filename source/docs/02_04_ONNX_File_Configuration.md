This section describes how to convert a PyTorch model to the ONNX format using the `torch.onnx.export()` function.  

**PyTorch to ONNX Conversion Example**  
You can export a PyTorch model to ONNX format as follows.  

Example  
```
import torch
import torch.nn as nn

# 1. Define or load the PyTorch model
class SimpleModel(nn.Module):
  def __init__(self):
    super().__init__()
    self.linear = nn.Linear(10, 5)    # Input 10, Output 5

  def forward(self, x):
    return self.linear(x)

model = SimpleModel()
model.eval()                 # Set to inference mode (Affect Dropout, BatchNorm, etc.)

# 2. Create a dummy input tensor with the same shape and type as the model input 
# This is used to trace the model’s computational graph, not for the actual inference 
batch_size = 1               # batch size must be 1
dummy_input = torch.randn(batch_size, 10)  # Create input matching the model’s input shape (Batch, Features)

# 3. Export the model to ONNX format  
onnx_file_path = "simple_model.onnx"

torch.onnx.export(
  model,                   # PyTorch model object to export 
  dummy_input,             # Dummy input used for tracing (tuple is possible)
  onnx_file_path,          # Output ONNX file path 
  export_params=True,      # If True, saves model parameter (weight) into the ONNX file 
  opset_version=11,        # ONNX opset version (11~21 supported)
  input_names=['input'],   # Name of the ONNX model input tensor 
  output_names=['output']  # Name of the ONNX model output tensor 
)
```

Key Parameter of `torch.onnx.export()`  

- `model`: PyTorch model object to export  
- `dummy_input`: Input values to model's `forward()` method  
- `onnx_file_path`: Output ONNX file path  
- `export_params`: If True, includes weights in the ONNX file  
- `opset_version`: ONNX opset version (11~21 supported)  
- `input_names`: Name of the input tensor(s)  
- `output_names`: Name of the output tensor(s)  

!!! note "NOTE"  
    - `model.eval()`: Set the model to "eval()" mode before exporting.  
    - `batch size`: Batch size **must** be 1.  

---
