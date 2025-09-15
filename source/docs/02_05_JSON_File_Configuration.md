This chapter describes various parameters required for compiling an ONNX model using the **DX_COM**. It includes input specifications, calibration methods, data preprocessing settings, and optional parameters for advanced compilation schemes.  
These parameters are defined in a JSON file, which serves as a blueprint for how the compiler interprets and processes the input model.  

### Required Parameters  

**DEEPX** provides the following required parameters for configuring JSON files. These parameters **must** be defined to successfully compile an ONNX model.  

**Inputs**  

Defines the input name and shape of the ONNX model.  

!!! warning "Model Input Restrictions"
    - The batch size **must** be fixed to 1.  
    - **Only** a single input is supported.  
    - Input name **must** exactly match ONNX model definition.

Example  
```
{
  "inputs": {
    "input.1": [1, 3, 512, 512]
  }
}
```

In this example, `"input.1"` is the name of the input tensor and its shape is `[1, 3, 512, 512]`, where:

- `1`: batch size (**must be 1**)  
- `3`: number of channels (e.g., RGB)  
- `512 x 512`: image height and width


**Calibration Method**  

Defines the calibration method used during quantization. It is essential for maintaining model accuracy after compilation by determining appropriate activation ranges.  

Available Methods

- `ema`:  
  Uses exponential moving average of activation values.  
  Recommended for improved post-quantization accuracy.  

- `minmax`:  
  Uses the minimum and maximum activation values to determine quantization range.

Example
```
{
  "calibration_method": "ema"
}
```

In this example, the ema method is selected to compute more stable and accurate quantization thresholds.  


**Calibration Number**  

Defines the number of steps used during calibration. A higher number may improve quantization accuracy by better estimating activation ranges, but may also increase compile time.  
To minimize the accuracy degradation, it is recommended to try different values, such as 1, 5, 10, 100, or 1000, and determine the value that yields the best accuracy for your model.

Example
```
{
  "calibration_num": 100
}
```

In this example, 100 samples from the calibration dataset will be used to determine activation ranges for quantization.


**Calibration Data Loader**  

Defines the dataset loader used during the calibration process. This parameter specifies the dataset location, accepted file types, and preprocessing steps to be applied before feeding data into the model.

Parameter

- `dataset_path`: The directory path where the calibration dataset is located.  
- `file_extensions`: A list of allowed file extensions for dataset files (case-sensitive). Only files with these extensions can be used.  
- `preprocessings`: Defines preprocessing steps applied to the calibration dataset. These steps should match the preprocessing used during inference to ensure consistency.  

Example
```
{
  "default_loader": {
    "dataset_path": "/datasets/ILSVRC2012",
    "file_extensions": ["jpeg", "png", "jpg", "JPEG"],
    "preprocessings": [...]
  }
}
```


**Input Preprocessing Operations in `default_loader`**  

The following preprocessing operations can be applied to input data for calibration or inference. TThese operations help standardize input formats and ensure consistency between calibration and deployment.  

*`convertColor`*  

Changes the color channel order of the input images. It is useful when the input image format (e.g., BGR or RGB) differs from what the model expects.  

Parameter  

- `form`: Defines the type of color space conversion.  
  - Supported values:`["RGB2BGR", "BGR2RGB", "BGR2GRAY", "BGR2YCrCb"]`  

Example
``` 
{
  "preprocessings": [
  {
    "convertColor": {
      "form": "BGR2RGB"
      }
    }
  ]
}
```

In this example, the color format is converted from BGR to RGB before being passed to the model.  


*`resize`*  

Resizes the input image to a specified target size.This operation is commonly used to match the model's expected input dimensions.  

Parameter

- `mode`
  : Defines the backend used for resizing.  
  : `default`: Uses OpenCV's resize function.  
  : `torchvision`: Uses PIL's resize function.  

- `size`
  : Defines the target output image size.  
  : Accepts list, tuple, or integer.  
  : Cannot be used with `width` and `height`.  

- `width, height`
  : Defines target width and height.  
  : Cannot be used with `size`.  

- `interpolation` (Optional)
  : Defines the interpolation method during resizing.  
  : Default: `"LINEAR"`  

| Mode           | Supported Interpolation Methods               |
|----------------|-----------------------------------------------|
| `default`      | `LINEAR`, `NEAREST`, `CUBIC`, `AREA`, `LANCZOS4` |
| `torchvision`  | `BILINEAR`, `NEAREST`, `BICUBIC`, `LANCZOS`     |

Example for `default` mode (OpenCV)
```
{
  "preprocessings": [
    {
      "resize": {
        "mode": "default",
        "width": 320,
        "height": 320,
        "interpolation": "LINEAR" # LINEAR, NEAREST, AREA, CUBIC, LANCZOS4
      }
    }
  ]
}
```

Example for `torchvision` mode (PIL-based) 
```
{
  "preprocessings": [
    {
      "resize": {
        "mode": "torchvision",
        "size": 250,
        "interpolation": "BILINEAR" # NEAREST, BILINEAR, BICUBIC, LANCZOC

      }
    }
  ]
}
```


*`centercrop`*

Crops the central region of the input image to the specified dimension. The crop is automatically centered based on the original image size.  

Parameter  

- `width`: The width of the crop region (in pixels)  
- `height`: The height of the crop region (in pixels)

Example
```
{
  "preprocessings": [
    {
      "centercrop": {
        "width": 224,
        "height": 224
      }
    }
  ]
}
```

In this example, a 224 × 224 region is cropped from the center of the input image.  


*`transpose`*  

Rearranges the dimensions of the input data based on the specified axis order. It is commonly used to convert between data formats.  

Paramater  

- `axis`: A list specifying the new order of axes

Example
```
{
  "preprocessings": [
    {
      "transpose": {
        "axis": [0, 2, 3, 1]
      }
    }
  ]
}
```

In this example, the tensor dimensions are rearranged to follow the `[batch, height, width, channels]` (NHWC) format.


*`expandDim`*  

Adds a new dimension to the input tensor at the specified axis. It is commonly used to insert a batch or channel dimension when required by the model.  

Parameter  

- `axis`: The axis index where the new dimension should be inserted

Example
```
{
  "preprocessings": [
    {
      "expandDim": {
        "axis": 0
      }
    }
  ]
}
```

In this example, a new dimension is added at axis 0, typically used to add a batch dimension to an image tensor.


*`normalize`*  

Normalizes the input data by applying mean and standard deviation values for each channel. This is commonly used to standardize input values before feeding them into a model.  

!!! warning "Warning"
    This preprocessing is accelerated by NPU. Thus, it **must not** be applied during NPU runtime.

Parameter  

- `mean`: A list of mean values for each channel (e.g., R, G, B)  
- `std`: A list of standard deviation values for each channel

Example
```
{
  "preprocessings": [
    {
      "normalize": {
        "mean": [0.486, 0.486, 0.486],
        "std": [0.229, 0.229, 0.229]
      }
    }
  ]
}
```

In this example, the same mean and standard deviation values are applied to all three channels, typically used for normalized RGB images.  


*`mul`*  
Multiplies the input data by a specified constant value. It is commonly used for scaling input pixel values.  

!!! warning "Warning"
    This preprocessing is accelerated by NPU. Thus, it **must not** be applied during NPU runtime.

Parameter  

- `x`: The constant value to multiply with the input data  

Example
```
{
  "preprocessings": [
    {
      "mul": {
        "x": 255
      }
    }
  ]
}
```

In this example, the input data is scaled by a factor of 255.  


*`add`*  

Adds a constant value to the input data. This operation is commonly used to adjust the input data by a fixed offset, such as shifting pixel values.  

!!! warning "Warning"
    This preprocessing is accelerated by NPU. Thus, it **must not** be applied during NPU runtime.

Parameter  

- `x`: The constant value to be added to each element of the input data  

Example
```
{
  "preprocessings": [
    {
      "add": {
        "x": 255
      }
    }
  ]
}
```

In this example, the value 255 is added to each element of the input data.  


*`subtract`*  
Subtracts a constant value from the input data. This operation is commonly used to adjust pixel intensity values or normalize data by removing a fixed offset.  

!!! warning "Warning"
    This preprocessing is accelerated by NPU. Thus, it **must not** be applied during NPU runtime. 

Parameter  

- `x`: The constant value to subtract from each element of the input data  

Example
```
{
  "preprocessings": [
    {
      "subtract": {
        "x": 255
      }
    }
  ]
}
```
In this example, the value 255 is subtracted from each element of the input data.  


*`div`*  

Divides the input data by a specified constant. It is commonly used to scale pixel values into a normalized range such as [0, 1].  

!!! warning "Warning"
    This preprocessing is accelerated by NPU. Thus, it **must not** be applied during NPU runtime. 

Parameter  

- `x`: The constant value to divide each element of the input data by (i.e., the divisor)  

Example
```
{
  "preprocessings": [
    {
      "div": {
        "x": 255
      }
    }
  ]
}
```

In this example, all input values are divided by 255.  

**Custom Loader**

If the model's input is not an image, you can use a custom loader to provide the input data during calibration. The user **must** provide a Python script that defines a custom dataset class.

*Guidelines for Writing a Dataset Class*  
Your custom dataset class **must** implement the following methods.  

- `__init__()`  
   : All constructor arguments **must** be optional, and have default values.  
- `__len__()`  
   : **Must** return the number of samples in the dataset.  
- `__getitem__()`  
   : **Must** return the data sample at the given index.  
   : The returned data **must** have a shape of either CHW (3-dimensional) or C.  (1-dimensional).  
   : The batch dimension (N) is automatically added by the system and is always set to 1.


Recommendation  

When using a custom loader, it is recommended to implement preprocessing logic directly within the dataset class, rather than relying on the preprocessing settings in the JSON configuration file.  

This approach offers the following benefits 

- Keeps data loading and transformation self-contained  
- Improve maintainability and debuggability  
- Provide flexibility for non-image input type


Example of `CustomDataset(Dataset)`  
```
  import pandas as pd
  import numpy as np
  from PIL import Image

  from torchvision import transforms
  from torch.utils.data import Dataset

  class CustomDataset(Dataset):
      def __init__(self, csv_path="./custom_loader_example/data/mnist_in_csv.csv", height=28, width=28):
        """
          Custom dataset example for reading data from csv

          Args: (should use default values for custom dataloader)
              csv_path (string): path to csv file
              height (int): image height
              width (int): image width
              transform: pytorch transforms for transforms and tensor conversion
        """
          self.data = pd.read_csv(csv_path)
          # self.labels = np.asarray(self.data.iloc[:, 0]) # not used for calibration
          self.height = height
          self.width = width
          self.transform = transforms.Compose([transforms.ToTensor()])
        
      def __len__(self):
          return len(self.data.index)

      def __getitem__(self, index):
          # Read each 784 pixels and reshape the 1D array ([784]) to 2D array ([28,28])
          img_as_np = np.asarray(self.data.iloc[index][1:]).reshape(self.height, self.width).astype('uint8')
        
         # Convert image from numpy array to PIL image, mode 'L' is for grayscale
          img_as_img = Image.fromarray(img_as_np)
          img_as_img = img_as_img.convert('L')

          # Transform image to tensor
          img_as_tensor = self.transform(img_as_img)
        
          # returned data shape should be CHW (3-dimensional) or C(1-dimensional)
          return img_as_tensor
```

*Using a Custom Loader in JSON configuration*  

To use a custom loader during calibration, you **must** specify the python dataset class in the JSON configuration.  

If the Python script file is named `dataset_module.py` and the dataset class is `CustomDataset`, the JSON configuration should be as follows.
```
{
  "custom_loader": {
    "package": “dataset_module.CustomDataset”
  }
}
```

The Python script file **must** be in the same directory as the dx_com executable before execution.  

Example
```
  dx_com 
  ├── calibration_dataset 
  ├── dataset_module.py
  ├── dx_com 
  │ ├── cv2/ 
  │ ├── google/ 
  │ ├── numpy/ 
  │ ├── ... 
  │ └── dx_com 
  ├── sample 
  │ ├── MobilenetV1.json 
  │ └── MobilenetV1.onnx 
  └── Makefile
```

See also: Download the [Custom Dataloader Guide”](https://developer.deepx.ai/wp-content/uploads/2024/09/Custom%20Dataloader%20Guide.zip) file for more detailed instruction. 

---
