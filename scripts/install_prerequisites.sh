#!/bin/bash

echo "Install dependencies..." && \
UBUNTU_VERSION=$(lsb_release -rs) && \
echo "*** UBUNTU_VERSION(${UBUNTU_VERSION}) ***" && \

# Version-specific packages (for dx-com and dx-tron)
if [ "$UBUNTU_VERSION" = "24.04" ]; then \
    sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        libgl1-mesa-dev libglib2.0-0 make \
        libfuse2 libayatana-appindicator3-1; \
elif [ "$UBUNTU_VERSION" = "22.04" ]; then \
    sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        libgl1-mesa-dev libglib2.0-0 make \
        libfuse2 libappindicator3-1 libgconf-2-4; \
elif [ "$UBUNTU_VERSION" = "20.04" ] || [ "$UBUNTU_VERSION" = "18.04" ]; then \
    sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        libgl1-mesa-dev libgl1-mesa-glx libglib2.0-0 make \
        libfuse2 libappindicator1 libgconf-2-4; \
else \
    echo "Unsupported Ubuntu version: $UBUNTU_VERSION" && exit 1; \
fi && \

# Common packages across all versions
sudo apt-get update && sudo apt-get install -y --no-install-recommends \
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
    libncursesw5-dev \
    libsqlite3-dev \
    tk-dev \
    libgdbm-dev \
    libc6-dev \
    libncurses5-dev \
    libnss3-dev \
    ccache \
    fuse libxss1 libxtst6 libnss3 \
    libcanberra-gtk-module libcanberra-gtk3-module \
    software-properties-common

sudo add-apt-repository -y universe && \
sudo apt-get update && sudo apt-get install -y \
    xdg-utils
