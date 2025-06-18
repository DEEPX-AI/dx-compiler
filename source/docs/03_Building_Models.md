This chapter describes the ONNX operations currently supported by DX-COM. When you build or export models to ONNX format, you **must** use only the supported operations to ensure successful compilation and optimal performance on our NPU.

---

## Supported ONNX Operations

The following ONNX operators are supported by the compiler.

### Common Conditions (Applicable to All Operation Types)

**Tensor Shape Limitations**

* **Width, height:** < 8,192
* **Channels:** < 32,768
* Dynamic shapes are not supported.

**Broadcasting Restrictions**

* In element-wise operations like Add, Div, Mul, and Sub, **channel-wise broadcasting** is not supported when the channel dimension size is greater than **1**.
* **Example:** A tensor with shape 1x24x24x1 (NHWC) cannot be broadcast to shape 1x24x24x32.

---

### Normal Operations

| **Operator** | **Supported Conditions** |
| :----------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add | Supports one of the following: <br> - Bias addition (e.g., from Gemm or Conv) <br> - Element-wise addition between tensors <br> - As part of input tensor normalization <br> - Constant scalar addition |
| ArgMax | Only supported when all of the following conditions are met: <br> - It is the last operation of the network. <br> - The preceding layer has a 2 or 4-dimensional output. <br> - Operates along the channel dimension. |
| AveragePool | `kernel_shape`: Height & Width < 32x32 |
| BatchNormalization | Fully supported. |
| Clip | Only supported as an activation function (e.g., ReLU6). |
| Concat | Fully supported. |
| Constant | Not supported if the constant is not a numeric data type. |
| ConstantOfShape | Fully supported. |
| Conv | **Common:** <br> - `dilations`: < 64 <br> - `pads`: < 64 <br> - `strides`: < 16 <br> **Standard Conv:** <br> - `kernel_shape`: Height & Width < 16 <br> **Depth-wise Conv:** <br> - `kernel_shape`: 3x3, 5x5 <br> Only constant weights are supported. |
| Div | Only one of the following: <br> - Constant scalar division <br> - As part of input tensor normalization |
| Dropout | Removed during inference. |
| Erf | Only supported as part of GELU. |
| Flatten | Only supported for reshaping Conv output into Dense input. |
| Gemm | Fully supported. |
| GlobalAveragePool | Fully supported. |
| Identity | Fully supported. |
| MatMul | Fully supported. |
| MaxPool | `kernel_shape`, `strides`: < 16 |
| Mul | Supports one of the following: <br> - Element-wise multiplication layer <br> - Constant scalar multiplication <br> - As part of input tensor normalization |
| Pad | `mode`: Only `constant` mode is supported. <br> Must be used before Pooling and Convolution. |
| ReduceMean | Only supported along the following dimensions: <br> - Channel <br> - Width, Height |
| ReduceSum | Only supported along the channel dimension. |
| Reshape | Only supported for squeeze-like operations. |
| Resize | Only supported with the following operator attributes: <br> - `coordinate_transformation_mode`: `pytorch_half_pixel` <br> - `mode`: `nearest` and `linear` <br> - `scales`: integer |
| Shape | This node cannot be specified as an output of the model. |
| Sigmoid | Fully supported. |
| Split | Input rank must be 4. |
| Squeeze | Fully supported. |
| Sub | Supports one of the following: <br> - Element-wise subtraction layer <br> - Constant scalar subtraction <br> - As part of input tensor normalization |
| Upsample (deprecated) | The scale in the N and C directions can only be 1. |

**Note:** Support for operations may vary depending on their combination within a model. Please use this document for general reference only. For specific use cases, please consult our technical support team.

---

### Activation Functions

| **Operator** | **Supported Conditions** |
| :----------- | :----------------------- |
| HardSwish | Fully supported. |
| HardSigmoid | Fully supported. |
| LeakyRelu | Fully supported. |
| Mish | Fully supported. |
| PRelu | Fully supported. |
| Relu | Fully supported. |
| Sigmoid | Fully supported. |
| Silu (Swish) | Fully supported. |
| Softplus | Fully supported. |
| Tanh | Fully supported. |