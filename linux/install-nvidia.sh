#!/bin/bash

BUILD_BASE=`pwd`
NV_FILE="NVIDIA-Linux-x86_64-375.39.run"
NV_URL="http://us.download.nvidia.com/XFree86/Linux-x86_64/375.39/${NV_FILE}"
NEED_TO_COMPILE_NV_KO=0

function clean_env() {

    [ -d ./${NV_DIR} ] && rm -rf ./${NV_DIR}
}

function check_env() {
    
    # check if in apollo kernel
    uname -r | grep apollo 1>/dev/null 2>&1 
    if [ $? -ne 0 ]
    then
        echo "Not in apollo kernel, Please install apollo kernel and reboot machine first."
        exit 2
    fi

    # check if nv ko already in kernel
    if [ ! -f /lib/modules/`uname -r`/kernel/drivers/video/nvidia.ko ]
    then
        export NEED_TO_COMPILE_NV_KO=1
    fi
}

function prepare_nv() {

    # download nv install file from nvidia home page 
    if [ ! -f ./${NV_FILE} ]
    then
       echo "Downloading ${NV_FILE} from nvidia website..."
        wget ${NV_URL} -O ${NV_FILE}
        if [ $? -ne 0 ]
        then
            echo "Downloading ${NV_FILE} failed, please check your network connection!"
            rm -rf ./${NV_FILE}
            exit 1
        fi
    fi

    # +x 
    chmod +x ./${NV_FILE}
    echo "Extracting nvidia install run file..."
    ./${NV_FILE} -x 1>/dev/null 2>&1
    NV_DIR="`echo ${NV_FILE} | awk -F '.run' '{print $1}'`"
    NV_VERSION="`echo ${NV_FILE} | awk -F '-' '{print $4}' | awk -F '.run' '{print $1}'`"

    export NV_DIR
    export NV_VERSION
    export NVIDIA_SOURCE="${NV_DIR}/kernel"
}

function install_lib() {
   
    NV_LIB_OUTPUT_PATH="/usr/lib/x86_64-linux-gnu/"
    NV_BIN_OUTPUT_PATH="/usr/bin/"

    [ -f ./${NV_DIR}/libnvidia-ml.so.${NV_VERSION} ] && /bin/cp -f ./${NV_DIR}/libnvidia-ml.so.${NV_VERSION} ${NV_LIB_OUTPUT_PATH}
    [ -f ./${NV_DIR}/libnvidia-fatbinaryloader.so.${NV_VERSION} ] && /bin/cp -f ./${NV_DIR}/libnvidia-fatbinaryloader.so.${NV_VERSION} ${NV_LIB_OUTPUT_PATH}
    [ -f ./${NV_DIR}/libnvidia-ptxjitcompiler.so.${NV_VERSION} ] && /bin/cp -f ./${NV_DIR}/libnvidia-ptxjitcompiler.so.${NV_VERSION} ${NV_LIB_OUTPUT_PATH}
    [ -f ./${NV_DIR}/libcuda.so.${NV_VERSION} ] && /bin/cp -f ./${NV_DIR}/libcuda.so.${NV_VERSION} ${NV_LIB_OUTPUT_PATH}
    [ -f ./${NV_DIR}/nvidia-modprobe ] && /bin/cp -f ./${NV_DIR}/nvidia-modprobe ${NV_BIN_OUTPUT_PATH}
    [ -f ./${NV_DIR}/nvidia-smi ] && /bin/cp -f ./${NV_DIR}/nvidia-smi ${NV_BIN_OUTPUT_PATH}

    chmod +x /usr/bin/nvidia*
    chmod +s /usr/bin/nvidia-modprobe

    # link for nvidia
    /bin/rm -rf /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1  /usr/lib/x86_64-linux-gnu/libnvidia-ml.so
    /bin/ln -s /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.${NV_VERSION} /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1
    /bin/ln -s /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1 /usr/lib/x86_64-linux-gnu/libnvidia-ml.so

    /bin/rm -rf /usr/lib/x86_64-linux-gnu/libcuda.so  /usr/lib/x86_64-linux-gnu/libcuda.so.1
    /bin/ln -s /usr/lib/x86_64-linux-gnu/libcuda.so.${NV_VERSION} /usr/lib/x86_64-linux-gnu/libcuda.so.1
    /bin/ln -s /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so

    # take effect
    /sbin/ldconfig 1>/dev/null 2>&1
}

function build_nv() {

    if [ ${NEED_TO_COMPILE_NV_KO} == 0 ]
    then
        return
    fi

    NVIDIA_MOD_REL_PATH='kernel/drivers/video'
    NVIDIA_OUTPUT_PATH="/lib/modules/`uname -r`/${NVIDIA_MOD_REL_PATH}"
    CPUNUM=`cat /proc/cpuinfo | grep processor | wc | awk -F " " '{print $1}'`

    export IGNORE_PREEMPT_RT_PRESENCE=true
    cd ${NVIDIA_SOURCE} && make -j ${CPUNUM} module
    cd ${BUILD_BASE}

    unset IGNORE_PREEMPT_RT_PRESENCE

    mkdir -p ${NVIDIA_OUTPUT_PATH}

    [ -f ${NVIDIA_SOURCE}/nvidia.ko ] && cp ${NVIDIA_SOURCE}/nvidia.ko ${NVIDIA_OUTPUT_PATH}
    [ -f ${NVIDIA_SOURCE}/nvidia-modeset.ko ] && cp ${NVIDIA_SOURCE}/nvidia-modeset.ko ${NVIDIA_OUTPUT_PATH}
    [ -f ${NVIDIA_SOURCE}/nvidia-drm.ko ] && cp ${NVIDIA_SOURCE}/nvidia-drm.ko ${NVIDIA_OUTPUT_PATH}
    [ -f ${NVIDIA_SOURCE}/nvidia-uvm.ko ] && cp ${NVIDIA_SOURCE}/nvidia-uvm.ko ${NVIDIA_OUTPUT_PATH}

    depmod -a
}

# check environment
check_env

# prepare for nvidia
prepare_nv

# build nvidia.ko
build_nv

# install user lib
install_lib

# clean environment
clean_env

echo "Done to install nvidia kernel driver and user libraries."
