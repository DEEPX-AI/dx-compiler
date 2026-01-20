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

## Download

DX-TRON can be downloaded from the **DEEPX Developers' Portal**:  
https://developer.deepx.ai

!!! note "NOTE"  
    Account registration and authentication are required to download DX-TRON packages.

For detailed installation instructions using the automated installation script, refer to the [dx-all-suite installation guide](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/installation.md#local-installation).

---

## Installation on Linux

**Supported Systems**

| **Operating System** | **Versions** | **Architecture** |
| :--- | :--- | :--- |
| Ubuntu | 20.04, 22.04, 24.04 | x86_64 (amd64), ARM64 (aarch64) |
| Debian | 11, 12, 13 | x86_64 (amd64), ARM64 (aarch64) |

DX-TRON can be installed using one of the following methods:

### Method 1: Automated Installation using install.sh (Recommended)

The easiest way to install DX-TRON is using the automated installation script. This script will download the package from DEEPX Portal, extract files to the `dx_tron/` directory, and install the Debian package automatically.

```bash
./install.sh --target=dx_tron --username=<your_email> --password=<your_password>
```

---

### Method 2: Manual DEB Package Installation

If you have already downloaded the DX-TRON package, you can manually install the Debian package.

**Step 1. Extract the Package**

```bash
tar xfz dxtron_x.y.z.tar.gz
```

This will extract the following files:
- `dxtron_x.y.z_amd64.deb` / `dxtron_x.y.z_arm64.deb`
- `dxtron_x.y.z_web/`
- `dxtron_x.y.z_amd64.AppImage`
- `dxtron_x.y.z_setup.exe`

**Step 2. Check Your System Architecture**

```bash
dpkg --print-architecture  # Returns: amd64 or arm64
```

**Step 3. Install the DEB Package**

```bash
# For x86_64 (amd64)
sudo apt-get install ./dxtron_x.y.z_amd64.deb

# For ARM64 (aarch64)
sudo apt-get install ./dxtron_x.y.z_arm64.deb
```

!!! note "NOTE"  
    The DEB package automatically handles all required dependencies. No additional package installation is needed.

---

### Method 3: AppImage (Portable)

AppImage is a portable executable that does not require system installation.

**Step 1. Install Required Packages**

DX-TRON AppImage requires several system libraries. Run the following command to install dependencies:

```bash
./scripts/install_prerequisites.sh
```

!!! note "NOTE"  
    `libfuse2` is mandatory for AppImage execution and may not be installed by default on Ubuntu 22.04 or later.

**Step 2. Prepare the AppImage File**

Make the AppImage executable:

```bash
chmod +x dxtron_x.y.z_amd64.AppImage
```

**Step 3. Run DX-TRON**

Execute the AppImage:

```bash
./dxtron_x.y.z_amd64.AppImage
```

Or use the convenience script:

```bash
./run_dxtron_appimage.sh
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

## Running DX-TRON

DX-TRON can be run in two modes: **Desktop GUI Mode** and **Web Server Mode**.

### Desktop GUI Mode

**After DEB Package Installation (Linux)**

Run DX-TRON using the `dxtron` command:

```bash
dxtron
```

**Using AppImage (Linux)**

Execute the AppImage file directly:

```bash
./dxtron_x.y.z_amd64.AppImage
```

Or use the convenience script:

```bash
./run_dxtron_appimage.sh
```

**On Windows**

Launch DX-TRON from the Start Menu or Desktop shortcut.

---

### Web Server Mode (Linux Only)

DX-TRON can be run as a local web server, allowing you to access the model viewer through a web browser.

**Basic Usage**

```bash
./run_dxtron_web.sh
```

Then open your browser and navigate to: `http://localhost:8080`

**Using a Different Port**

```bash
./run_dxtron_web.sh --port=3000
```

Then access: `http://localhost:3000`

!!! note "NOTE"  
    The web server mode requires the `dxtron_x.y.z_web/` directory, which is created after running `install.sh` or extracting the downloaded package.

For additional options, run:

```bash
./run_dxtron_web.sh --help
```

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
chmod +x dxtron_x.y.z_amd64.AppImage
```

  2) Verify Required Libraries (Linux)  
    - Confirm all dependencies are installed.  

  3) Reinstall DX-TRON  
    - Uninstall and reinstall DX-TRON to ensure all files are properly installed.  

---
