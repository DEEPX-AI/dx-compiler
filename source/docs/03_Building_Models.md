This chapter describes the ONNX operations currently supported by DX-COM.
When building or exporting models to ONNX format, you **must** use only the supported operations to ensure successful compilation and optimal performance.

## Supported ONNX Operations
The following ONNX operators are supported by the compiler.

**Common Conditions** (Applicable to All Operation Types)  

Tensor Shape Limitations  

- Width, height: < 8,192  
- Channels:  < 32,768  
- Dynamic shapes are not supported  
- Broadcasting Restrictions  
  : In element-wise operations such as Add, Div, Mul, and Sub, channel-wise broadcasting is not supported when the size of the channel dimension is  greater than **1**.  
  : Example: A tensor with shape 1x24x24x1 (NHWC) cannot be broadcast to shape 1x24x24x32.

**Normal Operations**  

| **Operator**        | **Supported Conditions**                            |
|---------------------|-----------------------------------------------------|
| Add                 | Supports one of the following <br> - Bias add(Gemm or Conv etc.) <br> - Element-wise Add (between tensor) <br> - As a part of input tensors normalization <br> - Const scalar addition |
| ArgMax              | Only supported when the following conditions are all met <br> - It is the last operation of the network. <br> - The layer before it has a 2 or 4 dimensional output. <br> - Operates along the channel dimension.  |
| AveragePool         | Kernel (Height&Width) < 32x32  |
| BatchNormalization  | Full Support  |
| Clip                | Only supported as an activation function (e.g., Relu6)   |
| Concat              | Full Support   |
| Constant            | Not supported one of the following <br> - When constant is not a numeric data type.  |
| ConstantOfShape     | Full Support  |
| Conv                | Common <br>  - Dilation < 64 <br>  - Pad size < 64 <br>  - Stride < 16 <br> Standard <br>  - Kernel(Height&Width) < 16 <br> Depth-wise Conv <br>  - Kernel: 3x3, 5x5 <br> Only constant weights are supported  |
| Div                 | Only one of the following <br> - Const scalar division - As a part of input tensors normalization |
| Dropout             | Removed when inference  |
| Erf                 | Only support as a part of GELU  |
| Exp                 | Only support as a part of Softmax  |
| Flatten             | Only to reshape Conv output into Dense input  |
| Gemm                | Full Support   |
| GlobalAveragePool   | Full Support   |
| Identity            | Full Support   |
| MatMul              | Full Support   |
| MaxPool             | kernel_shape, Stride < 16   |
| Mul                 | Supports one of the following <br> - Element-wise multiplication layer <br> - Const scalar multiplication <br> - As a part of input tensors normalization  |
| Pad                 | Constant mode is only supported. <br>  Before Pooling and Convolution. |
| ReduceMax           | Only supported as a part of Softmax  |
| ReduceMean          | Only supported along the following dimensions <br> - Channel <br> - Width, Height  |
| ReduceSum           | Only supported along the channel dimension.  |
| Resize              | Only supported in the following operator attribute <br> - coordinate_transformation_mode: pytorch_half_pixel <br> - mode: nearest and liner. <br> - scale: integer  |
| Shape               | This node cannot be specified as an output of the model.  |
| Sigmoid             | Full Support  |
| Slice               | Supports along the following dimension <br> - Input dimension is 4 <br> - Height or Width <br> - Channel with the number of 64   |
| Split               | Supports along the following dimension <br> - Input dimension is 4 <br> - Height or Width <br> - Channel with the number of 64   |
| Squeeze             | Full Support  |
| Sub                | Supports one of the following <br> - Element-wise subtraction layer <br> - Const scalar subtraction <br> - As a part of input tensors normalization <br> - Only as a part of Softmax  |
| Upsample (deprecated) | The scale in the N, C directions can only be 1  |

**Activation Functions**  

| **Operator**     | **Supported Conditions**                            |
|------------------|-----------------------------------------------------|
| HardSwish        | Full Support  |
| HardSigmoid      | Full Support  |
| LeakyRelu        | Full Support  |
| Mish             | Full Support  |
| PRelu            | Full Support  |
| Relu             | Full Support  |
| Sigmoid          | Full Support  |
| Silu (Swish)     | Full Support  |
| Softplus         | Full Support  |
| Softmax          | Only supported in channel dimension  |
| Tanh             | Full Support  |

---
