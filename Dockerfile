FROM ubuntu:20.04 as base
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ='Asia/Shanghai'

RUN ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && sed -i "s@http://.*.ubuntu.com@http://mirrors.cernet.edu.cn@g" /etc/apt/sources.list \
    && apt update
RUN apt install -y ca-certificates

RUN apt install -y sudo
RUN apt install -y ssh
RUN apt install -y netplan.io

# resizerootfs
RUN apt install -y udev
RUN apt install -y parted

# ifconfig
RUN apt install -y net-tools

# needed by knod-static-nodes to create a list of static device nodes
RUN apt install -y kmod

# Install our resizerootfs service
COPY root/etc/systemd/ /etc/systemd

RUN systemctl enable resizerootfs
RUN systemctl enable ssh
RUN systemctl enable systemd-networkd
RUN systemctl enable setup-resolve

RUN mkdir -p /opt/nvidia/l4t-packages
RUN touch /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall

COPY root/etc/apt/ /etc/apt
COPY root/usr/share/keyrings /usr/share/keyrings
RUN echo 'APT::Acquire::Retries "3";' >> /etc/apt/apt.conf.d/80-retries \
    && apt update

# nv-l4t-usb-device-mode
RUN apt install -y bridge-utils

# https://docs.nvidia.com/jetson/l4t/index.html#page/Tegra%20Linux%20Driver%20Package%20Development%20Guide/updating_jetson_and_host.html
RUN apt install -y -o Dpkg::Options::="--force-overwrite" \
    nvidia-l4t-core \
    nvidia-l4t-init \
    nvidia-l4t-bootloader \
    nvidia-l4t-camera \
    nvidia-l4t-initrd \
    nvidia-l4t-xusb-firmware \
    nvidia-l4t-kernel \
    nvidia-l4t-kernel-dtbs \
    nvidia-l4t-kernel-headers \
    nvidia-l4t-cuda \
    jetson-gpio-common \
    python3-jetson-gpio

RUN rm -rf /opt/nvidia/l4t-packages

COPY root/ /

RUN useradd -ms /bin/bash jetson
RUN echo 'jetson:jetson' | chpasswd

RUN usermod -a -G sudo jetson

RUN apt install -y --no-install-recommends ubuntu-desktop

RUN apt install -y python3 python3-pip python3-dev cmake git python3-numpy build-essential libgtk2.0-dev pkg-config \
    libavcodec-dev libavformat-dev libswscale-dev libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev ffmpeg libsm6 \
    libxext6 libgl1-mesa-glx libdc1394-22-dev libhdf5-dev git \
    python3-pyqt5 python3-pyqt5.qtquick qml-module-qtquick-controls2 qml-module-qt-labs-platform qtdeclarative5-dev \
    qml-module-qtquick2 qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools qml-module-qtquick-layouts qml-module-qtquick-window2

RUN mkdir -p /etc/udev/rules.d/ \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"' | tee /etc/udev/rules.d/80-movidius.rules \
    && python3 -m pip config set global.extra-index-url "https://mirrors.cernet.edu.cn/pypi/simple" \
    && python3 -m pip install --upgrade pip

USER jetson
WORKDIR /home/jetson
ENV WORKON_HOME=/home/jetson/.virtualenvs
ENV VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
ENV WORKON_HOME=/home/jetson/.virtualenvs

RUN python3 -m pip install virtualenv virtualenvwrapper \
    && echo "export WORKON_HOME=$HOME/.virtualenvs" >> ~/.bashrc \
    && echo "export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3" >> ~/.bashrc \
    && echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc \
    && echo "export OPENBLAS_CORETYPE=ARMV8" >> ~/.bashrc \
    && mkvirtualenv depthAI -p python3 \
    && git clone https://github.com/luxonis/depthai-python.git \
    && cd depthai-python/examples \
    && /home/jetson/.virtualenvs/depthAI/bvin/python install_requirements.py
