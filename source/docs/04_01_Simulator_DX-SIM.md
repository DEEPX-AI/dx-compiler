**DeepX** offers a simulator **(DX-SIM)** for testing the accuracy of optimized models without actual NPU hardware. 

- Executes the compiled model `(.dxnn)` and returns the output values.
- Is useful for validating model performance and behavior after compilation.
- Runs via Python interface, making it easy to integrate into existing workflows.

### System Requirements  

This section describes the hardware and software requirements for running the **DX-SIM**. 

**Hardware and Software Requirements**  

- CPU: x86(x64)  
- RAM: ≥16GB (32 GB or more recommended)  
- Storage: ≥8GBavailable disk space  
- OS: Ubuntu 18.04, 20.04, 22.04 (x64)  
- LDD version: ≥2.28  
- Python:	3.11 (It is recommended to use virtual environment)

### Installation of DX-SIM  

This section provides instructions for installing **DX-SIM**.  

- Run the following command to install the package.
```
$ pip install dx_simulator-xxx-cp311-cp311-linux_x86_64.whl
```
Replace xxx with the actual version number of the `.whl` file.

### How to Use  

This section describes how to initialize and use the DX-SIM simulator.  

**Create a Simulator Object**

To initialize the simulator, create a Simulator object by providing the path to the compiled `.dxnn` file. You may also enable GPU acceleration to improve simulation performance.  

Example of Creating an Object
```
python

from dx_simulator import Simulator

simulator = Simulator(
  model_path="path/to/graph.dxnn", 
  use_gpu=True,                   # Enable GPU acceleration (optional)
)
```

This example shows how to create a Simulator object by specifying the path to the compiled `.dxnn` model file. The use_gpu option can be set to True to optionally accelerate simulation using GPU.

**Simulator Method Description**  

| **Method Name**  | **Description**  | **Arguments**  |
|------------------|------------------|----------------|
| run              | Executes the simulator and returns outputs based on specified input. | `output_names (List[str])`: List of output tensor names. <br> `input_feed (Dict[str, np.ndarray])`: Dictionary mapping input names to NumPy arrays.        |
| get_preprocessing  | Returns the simulator's input preprocessing module, generated from the compilation config file `(.json)`  | None  |
| get_inputs       | Returns metadata about the model’s input tensors  | None  |
| get_outputs      | Returns the names of the model’s output tensors  | None  |


**Example Code - Running a Model with DX-SIM**  

This example demonstrates how to use **DX-SIM** to run inference on a compiled .dxnn model. It includes reading an image, applying the model's preprocessing, executing the simulation, and post-processing the output results.

```
python

import cv2
import numpy as np
from dx_simulator import Simulator

# Define post-processing logic
def post_process(outputs: List[np.ndarray]):
# Implement your post-processing here
…

# Create a Simulator object
dxnn_path = “graph.dxnn”
simulator = Simulator(model_path=dxnn_path)

# Load the preprocessing module
preprocess = simulator.get_preprocessing() 

# Read and preprocess the input image
image_file_path = "image.png"
input_image = cv2.imread(image_file_path)
preprocessed_image = preprocess(input_image).astype(np.uint8)

# Run the simulator
outputs = simulator.run(
  output_names=["output1", "output2", "output3"],
  input_feed={"input": preprocessed_image}
  )

# Apply post-processing
output = post_process(outputs
)
```

**Note.** You can replace the default preprocess function with your own. However, it must align with the configuration used during compilation–any mismatch may lead to reduced accuracy.  
Additionally, avoid including arithmetic operations  (e.g., normalization) in the custom preprocessing, as these are handled internally by the NPU.  

### Example: YOLOv5s with DX-SIM  

This example shows how to run a YOLOv5s model compiled as a `.dxnn` file using **DX-SIM**, apply post-processing with PyTorch and Ultralytics utilities, and visualize detection results.  

```
python

import cv2
import numpy as np
import torch
import torchvision
from ultralytics.utils import ops
from dx_simulator import Simulator

# Paths
model_path = "yolov5s.dxnn"
image_path = "test_img.jpg"
result_path = "result.jpg" 

# Initialize the simulator
simulator = Simulator(model_path=model_path)
preprocess = simulator.get_preprocessing()

# Read and preprocess the image
image = cv2.imread(image_path)
preprocessed_image = preprocess(image)

# Run the simulator
input_names = simulator.get_inputs()
output_names = simulator.get_outputs()
pred = simulator.run(output_names, {input_names[0].name: preprocessed_image})[0]

# Post-process the outputs (YOLOv5-style)
conf_thres, iou_thres = 0.25, 0.45
x = torch.Tensor(pred[0])
x = x[x[..., 4] > conf_thres]
box = ops.xywh2xyxy(x[:, :4])
x[:, 5:] *= x[:, 4:5]
conf, j = x[:, 5:].max(1, keepdims=True)
x = torch.cat((box, conf, j.float()), 1)[conf.view(-1) > conf_thres]
x = x[x[:, 4].argsort(descending=True)]
x = x[torchvision.ops.nms(x[:, :4], x[:, 4], iou_thres)]

# Visualize the results
image = cv2.cvtColor(preprocessed_image[0], cv2.COLOR_RGB2BGR)
colors = np.random.randint(64, 256, [80, 3], np.uint8).tolist()
for r in x.numpy():
pt1, pt2, conf, label = r[0:2].astype(int), r[2:4].astype(int), r[4], r[5].astype(int)
image = cv2.rectangle(image, pt1, pt2, colors[label], 2)

cv2.imwrite(result_path, image)
print("The resulting image is saved at ->", result_path
)
```

---
