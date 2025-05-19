This section provides instructions for installing required libraries and setting up **DX-COM** on supported Ubuntu distributions.  

**Install the Required Libraries**

Before installing **DX-COM**, ensure the following libraries are installed.  

- `libgl1-mesa-glx`: Provides OpenGL runtime support for graphical operations  
- `dlibglib2.0-0`: Core utility library used by many GNOME and GTK applications  

<br>
- Run the following command to install the required libraries.
```
sudo apt-get install -y --no-install-recommends libgl1-mesa-glx libglib2.0-0 make
```

**Install DX-COM**

**DX-COM** supports the Target OS of Ubuntu 18.04, Ubuntu 20.04, Ubuntu 22.04, and Ubuntu 24.04.  

- After downloading the compiler archive, extract it using the following command.  
```
tar xfz dx_com_M1_vx.x.x.tar.gz
```

After extraction, the directory `dx_com/` will contain the compiler executables, sample ONNX models, JSON configuration files, a sample `Makefile` for compilation.  

---
