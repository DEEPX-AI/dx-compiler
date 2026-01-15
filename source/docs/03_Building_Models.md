# Supported ONNX Operators

This chapter describes the ONNX operations currently supported by DX-COM. When you build or export models to ONNX format, you **must** use only the supported operations to ensure successful compilation and optimal performance on our NPU.  

---

## Operator Support Details

The following ONNX operators are supported by the compiler.  

### Common Conditions (Applicable to All Operation Types)

**Tensor Shape Limitations**  

- **Width, height:** < 8,192  
- **Channels:** < 32,768  
- Dynamic shapes are not supported.  

**Broadcasting Restrictions**  

- In element-wise operations like Add, Div, Mul, and Sub, **channel-wise broadcasting** is not supported when the channel dimension size is greater than **1**.  
- **Example:** A tensor with shape 1x24x24x1 (NHWC) cannot be broadcast to shape 1x24x24x32.  

---

### Normal Operations

| **Operator** | **Supported Conditions** |
| :--- | :--- |
| Add | Supported as: <br> - Bias addition (e.g., as part of `Gemm` or `Conv`) <br> - Element-wise addition <br> - Used for input normalization <br> - Constant scalar addition |
| ArgMax | Only supported if all of the following hold: <br> - It is the final operation in the network <br> - The preceding output is 2D or 4D <br> - It operates along the channel dimension |
| AveragePool | - `kernel_shape` < 32 <br> - `strides` < 32 |
| BatchNormalization | No restrictions |
| Clip | Only supported as an activation function (e.g., ReLU6) |
| Concat | No restrictions |
| Constant | Only numeric constants are supported |
| ConstantOfShape | No restrictions |
| Conv | **Common constraints:** <br> - `dilations` < 64 <br> - `pads` < 64 <br> - `strides` < 16 <br> **Standard Conv:** <br> - `kernel_shape` < 16 <br> **Depth-wise Conv:** <br> - `kernel_shape` ∈ {[3, 3], [5, 5]} <br> - Only constant weights are supported |
| ConvTranspose | - `dilations` = [1, 1] <br> - `output_padding` = [0, 0] <br> - `pads` ≤ 14 <br> - `strides` ∈ [2, 8] <br> - `kernel_shape` < 16 <br> - `group` = 1 |
| Div | Supported as: <br> - Constant scalar division <br> - Input normalization <br> - Part of `Softmax` <br> - Part of `LayerNorm` |
| Dropout | Removed during inference |
| Erf | Only supported as part of `GELU` |
| Flatten | No restrictions |
| Gather | Supported when `indices` is a 0-D or 1-D tensor. <br> Examples: <br> - Scalar index: `indices = [0]` to select first element <br> - 1-D index: `indices = [0, 2, 5]` to select multiple elements |
| Gemm | No restrictions |
| GlobalAveragePool | No restrictions |
| Identity | No restrictions |
| MatMul | No restrictions |
| MaxPool | - `kernel_shape` < 16 <br> - `strides` < 16 |
| Mul | Supported as: <br> - Element-wise multiplication <br> - Constant scalar multiplication <br> - Input normalization |
| Pad | - Only `mode=constant` is supported <br> - Must precede a `Pool` or `Conv` operation |
| ReduceMean | Only supported when reducing along: <br> - Channel dimension <br> - (Width, Height) dimensions |
| ReduceSum | Only supported when reducing along the channel dimension |
| Reshape | No restrictions |
| Resize | Only supported with the following attributes: <br> - `coordinate_transformation_mode` = `pytorch_half_pixel` <br> - `mode` ∈ {`nearest`, `linear`} <br> - Scale values ∈ ℤ (integers) |
| Shape | Cannot be used as a model output |
| Slice | No restrictions |
| Softmax | Only supported if the size of the input along the specified `axis` is ≤ 4080 |
| Split | No restrictions |
| Squeeze | No restrictions |
| Sub | Supported as: <br> - Element-wise subtraction <br> - Constant scalar subtraction <br> - Input normalization |
| Transpose | No restrictions |

---

### Activation Functions

| **Operator** | **Supported Conditions** |
| :--- | :--- |
| HardSwish | No restrictions |
| HardSigmoid | No restrictions |
| LeakyRelu | No restrictions |
| Mish | No restrictions |
| PRelu | No restrictions |
| Relu | No restrictions |
| Sigmoid | No restrictions |
| Silu (Swish) | No restrictions |
| Softplus | No restrictions |
| Tanh | No restrictions |

---

### Deprecated Operations

The following operations are deprecated in ONNX and maintained here only for backward compatibility. Their usage is discouraged in new models and may be removed in future versions.  
Please use alternative operators where possible.  

| **Operator** | **Supported Conditions** |
| :--- | :--- |
| Upsample | Only supported when scale values in the N and C dimensions are 1 |

!!! note "NOTE"  
    The operator support may vary depending on how operations are combined within a model. This document is intended as a general guideline. For validation of specific use cases, please contact our technical support team.

---
