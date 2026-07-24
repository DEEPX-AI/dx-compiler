This section describes the hardware and software requirements for running **DX-COM**.  

**Hardware and Software Requirements**  

- **CPU:** amd64(x86_64)  
     NOTE. aarch64(arm64) is **NOT** supported.  
- **RAM:** ≥ 16 GB  
- **Storage:** ≥ 8 GB available disk space  
- **OS:** Ubuntu 20.04 / 22.04 / 24.04 / 26.04 (x86_64, primary supported environments; Ubuntu 26.04 validated in DX-COM v2.4.0). Fedora 42-45, Red Hat Enterprise Linux 9-10, and CentOS Stream 9-10 have been **validated since DX-COM v2.3.0** and continue to be supported in v2.4.0.  
     NOTE. Ubuntu 18.04 OS is **NOT** supported.  
- **glibc:** ≥ 2.31 (matches the `manylinux_2_31_x86_64` wheel platform tag)  

!!! note "NOTE"  
    To check your glibc version, run `ldd --version` in the terminal.  

![Figure. DX-M1 M.2 Module](./../resources/02_DX-M1_M.2_LPDDR5x2_PCP.png){ width=600px }

 ---
