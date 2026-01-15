## Overview

**DX-TRON** is a graphical visualization tool for exploring .dxnn model files compiled with the DEEPX toolchain.  
It allows users to load and inspect model structures, view workload distribution between NPU and CPU through color-coded graphs. With **DX-TRON**, users can better understand model execution flow and improve overall performance.  

**Key Features**

- **Support for .dxnn Files**: Load and visualize model files compiled with the DEEPX toolchain.  

- **Visual Workload Representation**: Displays a color-coded breakdown of workload execution:  
    - Red: Operations executed on the NPU  
    - Purple: Operations executed on the CPU or host  

- **Interactive Node Inspection** : Double-click any node within the graph to view detailed information about the associated operations.  

![Figure. DX-TRON Interactive Node Details](../resources/04_02_DX-TRON_Interactive_Node_Details.png){ width=500px }


- **Model Navigation Controls**: Use the backward arrow in the bottom-left corner to return to the model overview screen at any time.  

![Figure. DX-TRON Navigation Controls](../resources/04_02_DX-TRON_Navigation_Controls.png){ width=600px }

---

## Installation on Linux
This section explains how to install and run DX-TRON on Ubuntu using the .AppImage file.

**Step 1. Install Required Packages**  
DX-TRON requires several system libraries to run. Run the following commands to install dependencies.  

``` 
./scripts/install_prerequisites.sh
```

!!! note "NOTE"  
    `libfuse2` is mandatory for AppImage execution and may not be installed by default on Ubuntu 22.04 or later.  

**Step 2. Prepare the AppImage File**  
Make the AppImage executable.  

```
chmod +x DXTron-x.y.z.AppImage
```

**Step 3. Run DX-TRON**   
Execute the AppImage.  

```
./DXTron-x.y.z.AppImage
```

![Figure. DX-Tron GUI Window](../resources/dx-tron_GUI_window.png){ width=500px }

Once launched, a GUI window will appear, enabling DXNN model visualization. 

!!! warning "Warning"  
    Running DX-TRON with `sudo` may require the `--no-sandbox` flag, but this is **not recommended** for security reasons.  

---

## Installation on Windows
This section explains how to install and launch DX-TRON on Windows using the provided setup file.

**Step 1. Installation File**  
- File Name: `DXTron Setup x.y.z.exe`

**Step 2. Installation Steps**  
  1) Save the provided .exe file to your PC.  
  2) Double-click the file to launch the installer.  
  3) When the User Account Control (UAC) prompt appears, click **Yes**.  
  4) Follow the on-screen instructions in the installation wizard.  
  5) After installation, a DX-TRON shortcut is created in the Start Menu and optionally on the Desktop.  

The default installation path is as follows.  

```
C:\Users\YourUsername\AppData\Local\Programs\DXTron\
```

**Step 3. Launching DX-TRON**  
- Search for DX-TRON in the Start Menu and run it, or  
- Double-click the Desktop shortcut (if created).

---

## Troubleshooting

**Step 1. Security Warnings on Windows**  
If Microsoft Defender SmartScreen blocks the installer:  
  1) Click More Info.  
  2) Select Run Anyway to continue installation.  

**Step 2. Program Fails to Launch**  
Perform the following checks in order.  
  1) Check AppImage Permission (Linux)    
    - Ensure the file is executable.  

```
chmod +x DXTron-x.y.z.AppImage
```

  2) Verify Required Libraries (Linux)  
    - Confirm all dependencies are installed.  

  3) Reinstall DX-TRON  
    - Uninstall and reinstall DX-TRON to ensure all files are properly installed.  

---
