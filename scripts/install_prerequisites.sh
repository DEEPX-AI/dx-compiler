#!/bin/bash

echo "Install dependencies..." && \
UBUNTU_VERSION=$(lsb_release -rs) && \
echo "*** UBUNTU_VERSION(${UBUNTU_VERSION}) ***" && \

# [Fix 3] Ensure universe repo is enabled BEFORE installing packages
sudo apt-get update && sudo apt-get install -y software-properties-common && \
sudo add-apt-repository -y universe && sudo apt-get update && \

# Version-specific packages
if [ "$UBUNTU_VERSION" = "24.04" ]; then \
    # [Fix 2] Use libncurses-dev instead of libncurses5-dev for 24.04
    # libfuse2 is safe (needed for AppImages), but 'fuse' package must be avoided
    sudo apt-get install -y --no-install-recommends \
        libgl1-mesa-dev libglib2.0-0 make \
        libfuse2 libayatana-appindicator3-1 \
        libncurses-dev; \
elif [ "$UBUNTU_VERSION" = "22.04" ]; then \
    sudo apt-get install -y --no-install-recommends \
        libgl1-mesa-dev libglib2.0-0 make \
        libfuse2 libappindicator3-1 libgconf-2-4 \
        libncurses5-dev libncursesw5-dev; \
elif [ "$UBUNTU_VERSION" = "20.04" ] || [ "$UBUNTU_VERSION" = "18.04" ]; then \
    sudo apt-get install -y --no-install-recommends \
        libgl1-mesa-dev libgl1-mesa-glx libglib2.0-0 make \
        libfuse2 libappindicator1 libgconf-2-4 \
        libncurses5-dev libncursesw5-dev; \
else \
    echo "Unsupported Ubuntu version: $UBUNTU_VERSION" && exit 1; \
fi && \

# Common packages across all versions
# [Fix 1] REMOVED 'fuse' package to prevent gnome-shell removal on 24.04
# [Fix 2] REMOVED 'libncurses5-dev/libncursesw5-dev' (moved to version specific blocks)
sudo apt-get install -y --no-install-recommends \
    libssl-dev \
    wget \
    openssl \
    build-essential \
    zlib1g-dev \
    patchelf \
    libffi-dev \
    ca-certificates \
    libbz2-dev \
    liblzma-dev \
    libsqlite3-dev \
    tk-dev \
    libgdbm-dev \
    libc6-dev \
    libnss3-dev \
    ccache \
    libxss1 libxtst6 libnss3 \
    libcanberra-gtk-module libcanberra-gtk3-module \
    xdg-utils

# Check if the installation was successful
if [ $? -eq 0 ]; then
    echo "Dependencies installed successfully."
else
    echo "Dependency installation failed."
    exit 1
fi
