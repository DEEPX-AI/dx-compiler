# Coding Standards — dx-compiler

> Standards for Python scripts, config files, and automation code
> in the dx-compiler agent-driven infrastructure.

## Python Standards

### Version & Runtime
- Python 3.8 - 3.12 (match DX-COM requirements)
- Use type hints for all function signatures
- Use `from __future__ import annotations` for forward references (3.8 compat)

### Imports

```python
# Standard library first
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Union

# Third-party second
import onnx
import torch

# DEEPX packages third
import dx_com
```

- Always use absolute imports
- Never use wildcard imports (`from module import *`)
- Group imports with blank lines: stdlib → third-party → DEEPX

### Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Functions | snake_case | `compile_model()` |
| Variables | snake_case | `output_dir` |
| Constants | UPPER_SNAKE | `DEFAULT_OPSET = 13` |
| Classes | PascalCase | `CompileResult` |
| Config keys | snake_case | `"calibration_method"` |
| File names | snake_case | `validate_framework.py` |

### Error Handling

```python
# Always catch specific exceptions
try:
    dx_com.compile(model=onnx_path, output_dir=out, config=cfg)
except FileNotFoundError as e:
    logger.error(f"Model not found: {e}")
    raise
except RuntimeError as e:
    logger.error(f"Compilation failed: {e}")
    raise

# Never use bare except
# Bad: except:
# Bad: except Exception:
```

### Logging

```python
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Use structured messages
logger.info("Compiling model=%s output=%s", model_path, output_dir)
logger.error("Compilation failed: %s", error_msg)
```

## config.json Conventions

### Key Rules
1. `inputs` key must **exactly** match ONNX model input node name
2. Input shape must **exactly** match ONNX model input shape
3. All spatial dimensions must be positive integers (no -1 or 0)
4. Batch dimension must always be 1

### Preprocessing Order
Preprocessings are applied in array order. Standard order:
1. `resize` — to model input dimensions
2. `normalize` — mean/std normalization

### Required Fields
```json
{
  "inputs": {},
  "calibration_method": "ema",
  "calibration_num": 100,
  "default_loader": {
    "dataset_path": "",
    "file_extensions": [],
    "preprocessings": []
  }
}
```

### Optional Fields
- `quantization_device` — GPU for calibration (e.g., `"cuda:0"`)
- `enhanced_scheme` — Advanced quantization (e.g., `{"DXQ-P3": {...}}`)
- `ppu` — Post-processing unit config for detection models

## Convention Checklist

Before submitting any code or config:

- [ ] Python type hints on all functions
- [ ] Imports grouped and ordered (stdlib → third-party → DEEPX)
- [ ] No bare `except` clauses
- [ ] All paths use `pathlib.Path` or `os.path`
- [ ] config.json inputs key matches ONNX input name
- [ ] Batch dimension is 1 in all shapes
- [ ] Error messages include context (file path, parameter name)
- [ ] Logging uses `logger`, not `print()`
- [ ] No hardcoded absolute paths (use parameters or env vars)
- [ ] No DEEPX credentials or API keys in committed code
