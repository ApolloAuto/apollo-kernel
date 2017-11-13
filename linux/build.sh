#!/bin/bash

#=================================================
#                   Utils
#=================================================
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${DIR}"

#get original linux kernel
function get_kernel() { 
  kernel_version="4.4.32"
  loadkernel_address="http://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${kernel_version}.tar.xz"
  if [ -e ./Makefile ]
  then
	return
  fi

  /bin/rm -rf ./linux-${kernel_version}*
  info "Downloading linux kernel code from ${loadkernel_address}..." 
  wget ${loadkernel_address} 1>/dev/null 2>&1 
  tar -xvf linux-${kernel_version}.tar.xz 1>/dev/null 2>&1
  rsync -a linux-${kernel_version}/* ${DIR}/
 }

START_TIME=$(($(date +%s%N)/1000000))
TIME=$(date  +%Y%m%d_%H%M)

function info() {
  (>&2 echo -e "[\e[34m\e[1mINFO\e[0m] $*")
}

function error() {
  (>&2 echo -e "[\e[33m\e[1mERROR\e[0m] $*")
}

function ok() {
  (>&2 echo -e "[\e[32m\e[1m OK \e[0m] $*")
}

function print_delim() {
  echo '============================'
}

function k_patch() {
    file=$1
    patch -p1 < ${file}
    if [ $? -ne 0 ]
    then
        fail "FAILED to patch $file, try ./build.sh clean first, exit"
    fi
}

function k_patch_r() {
    file=$1
    patch -R -p1 -f < ${file}
    if [ $? -ne 0 ]
    then
        fail "FAILED to revert patch $file, try ./build.sh clean first, exit"
    fi
}

print_time() {
  END_TIME=$(($(date +%s%N)/1000000))
  ELAPSED_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000" | bc -l)
  MESSAGE="Took ${ELAPSED_TIME} seconds"
  info "${MESSAGE}"
}

function success() {
  print_delim
  ok "$1"
  print_time
  print_delim
}

function fail() {
  print_delim
  error "$1"
  print_time
  print_delim
  exit -1
}

get_kernel

_VERSION=`grep "VERSION =" Makefile |awk -F " " '{if ($1=="VERSION") print $3;}'`
_PATCHLEVEL=`grep "PATCHLEVEL =" Makefile | awk -F " " '{if ($1=="PATCHLEVEL") print$3;}'`
_SUBLEVEL=`grep "SUBLEVEL =" Makefile | awk -F " " '{if ($1=="SUBLEVEL") print$3;}'`

_KERNEL_VERSION="${_VERSION}.${_PATCHLEVEL}.${_SUBLEVEL}${EXTVER}"
_CONFIG_FILE="configs/config.${_VERSION}.${_PATCHLEVEL}.${_SUBLEVEL}"

CPUNUM=`cat /proc/cpuinfo | grep processor | wc | awk -F " " '{print $1}'`
OUTPUTDIR="install"

export CPUNUM
export OUTPUTDIR

# +x for other build scripts
chmod +x ./build*.sh ./install*.sh

function save_esd_files() {
  rm -rf drivers/esdcan.m
  cp -r drivers/esdcan drivers/esdcan.m
}

function restore_esd_files() {
  cp -r drivers/esdcan.m/* drivers/esdcan
  rm -rf drivers/esdcan.m
}

#=================================================
#              Build functions
#=================================================
function kernel_clean() {
    make distclean
    # ESD files are added manually, save them as "git clean" would remove them.
    save_esd_files
    git clean -f
    git reset --hard HEAD
    restore_esd_files

    if [ $? -ne 0 ];then
        fail "Error: reset git repo failed!"
    fi
    if [ -d ${OUTPUTDIR} ];then
        rm -rf ${OUTPUTDIR}
        if [ $? -ne 0 ];then
            fail "Error: Remove output dir failed!"
        fi
    fi
    success "Cleanup done."
}

function kernel_cleanall() {
    make distclean
    git clean -f
    git reset --hard HEAD

    if [ $? -ne 0 ];then
        fail "Error: reset git repo failed!"
    fi
    if [ -d ${OUTPUTDIR} ];then
        rm -rf ${OUTPUTDIR}
        if [ $? -ne 0 ];then
            fail "Error: Remove output dir failed!"
        fi
    fi
    success "Cleanup done."
}

function kernel_patch() {
    # patch pre_rt.patch
    grep '#res' scripts/setlocalversion > /dev/null
    if [ $? -ne 0 ]; then
        k_patch patches/pre_rt.patch
    fi
    # patch esdcan
    if [ ! -d drivers/esdcan ]; then
        k_patch patches/esdcan.patch
    fi
    # patch e1000e.patch
    grep E1000_DEV_ID_PCH_LBG_I219_LM3 drivers/net/ethernet/intel/e1000e/hw.h > /dev/null
    if [ $? -ne 0 ]; then
        k_patch patches/e1000e.patch
    fi
    # patch inet_csk_clone_lock_double_free.patch
    grep mc_list ./net/ipv4/inet_connection_sock.c > /dev/null
    if [ $? -ne 0 ]; then
        k_patch patches/inet_csk_clone_lock_double_free.patch
    fi
    # patch cve_security.patch
    grep ahash_notify_einprogress crypto/ahash.c > /dev/null
    if [ $? -ne 0 ]; then
        k_patch patches/cve_security.patch
    fi
}

function prepare_nonrt() {
    # build Non-RT kernel
    success "build Non-RT kernel"

    [ -f Makefile.bak ] || cp Makefile Makefile.bak
    EXTVER=`grep "EXTRAVERSION =" Makefile.bak | awk -F " " '{print$3;}'`
    sed -e "s/EXTRAVERSION = ${EXTVER}/EXTRAVERSION = ${EXTVER}-NonRT/" Makefile.bak  > Makefile
    _KERNEL_VERSION="${_VERSION}.${_PATCHLEVEL}.${_SUBLEVEL}${EXTVER}-NonRT"

    grep 'config PREEMPT_RT_FULL' kernel/Kconfig.preempt > /dev/null
    if [ $? -eq 0 ]; then
        k_patch_r patches/patch-4.4.32-rt43.patch
        k_patch_r patches/nvidia-hung-semaphore-completion.patch
        rm -f localversion-rt*
    fi

    export RT_VERSION=nonrt
    export _KERNEL_VERSION
}

function prepare_rt() {
    # build Non-RT kernel
    success "build RT kernel"

    [ -f Makefile.bak ] || cp Makefile Makefile.bak
    EXTVER=`grep "EXTRAVERSION =" Makefile.bak | awk -F " " '{print$3;}'`
    sed -e "s/EXTRAVERSION = ${EXTVER}/EXTRAVERSION = ${EXTVER}-RT/" Makefile.bak  > Makefile
    _KERNEL_VERSION="${_VERSION}.${_PATCHLEVEL}.${_SUBLEVEL}${EXTVER}-RT"

    grep 'config PREEMPT_RT_FULL' kernel/Kconfig.preempt > /dev/null
    if [ $? -ne 0 ]; then
        k_patch patches/patch-4.4.32-rt43.patch
        k_patch patches/nvidia-hung-semaphore-completion.patch
        rm -f localversion-rt*
    fi
    export RT_VERSION=rt
    export _KERNEL_VERSION
    export _CONFIG_FILE=${_CONFIG_FILE}.rt
}

# Prints the given message in red txt with white background.
function echo_red_white {
   echo -e "$(tput setaf 1)$(tput setab 7)"$1 "\e[0m"
}

# Checks if ESD CAN driver is there, very superficial check.
function check_esd_files() {
  if [ -f ./drivers/esdcan/Makefile \
      -a -f ./drivers/esdcan/Kconfig \
      -a -f ./drivers/esdcan/esdcan.h ]; then
    echo 1
  else
    echo 0
  fi
}
function kernel_build() {
    # make
    cp -f ${_CONFIG_FILE} .config
    if [ $? -ne 0 ];then
      fail "no available config."
    fi

    # ESD CAN driver
    if [ $(check_esd_files) -eq 0 ]; then
      echo_red_white "To support ESD CAN, ESD CAN driver supplied by ESD Electronics is required , but not found."
      echo_red_white "Please refer to ESDCAN-README.md for more information."
      echo_red_white "Build will continue after 6 seconds, but ESD CAN support will not be built-in; "
      echo_red_white "type ctrl+c to interrupt if that's not what you want."
      sleep 6
      # Create empty kernel config file to make config happy
      if [ ! -f ./drivers/esdcan/Kconfig ]; then
        echo "" > ./drivers/esdcan/Kconfig
      fi
      if [ ! -f ./drivers/esdcan/Makefile ]; then
        echo "" > ./drivers/esdcan/Makefile
      fi
    else
      echo "CONFIG_ESDCAN=m" >> .config
      echo_red_white "Will build with ESD CAN support"
    fi

    make oldconfig
    make -j ${CPUNUM}
    if [ $? -ne 0 ];then
        fail "Error: Make failed!"
        exit 1
    fi

    export INSTALL_PATH=${OUTPUTDIR}/${RT_VERSION}
    mkdir -p ${INSTALL_PATH}

    # install
    make modules_install INSTALL_MOD_PATH=${INSTALL_PATH}

    cp arch/x86/boot/bzImage ${INSTALL_PATH}/vmlinuz-${_KERNEL_VERSION}
    cp System.map ${INSTALL_PATH}/System.map-${_KERNEL_VERSION}
    cp .config ${INSTALL_PATH}/config-${_KERNEL_VERSION}
    cp install*.sh ${INSTALL_PATH}

    # build header
    # TODO to replace with an elegant method
    rsync -a scripts ${INSTALL_PATH}/linux-headers-${_KERNEL_VERSION}/
    rsync -a arch block certs crypto Documentation drivers firmware fs include init ipc Kbuild Kconfig kernel lib Makefile mm modules.builtin modules.order Module.symvers net samples security sound System.map tools usr virt ${INSTALL_PATH}/linux-headers-${_KERNEL_VERSION}/ --exclude=*.c --exclude=*.ko --exclude=*.o --exclude=.git* --exclude=*.dts* --exclude=*.S --exclude=*.txt --exclude=*o.cmd
    for i in `find ${INSTALL_PATH}/linux-headers-${_KERNEL_VERSION}/ -type f|grep -v Kconfig|grep -v Makefile|grep -v Kbuild|grep -v pl |grep -v include|grep -v .sh|grep -v scripts|grep -v arch|grep -v Module|grep -v module |grep -v .config |grep -v System.map |grep -v .vmlinux.cmd |grep -v .version`; do rm -rf $i; done

    cd ${INSTALL_PATH}
    depmod -a -b . -w ${_KERNEL_VERSION}

    mv lib/* . && rm -r lib
    # remove source link
    rm -f modules/${_KERNEL_VERSION}/source
    rm -f modules/${_KERNEL_VERSION}/build
    ln -s /usr/src/linux-headers-${_KERNEL_VERSION} modules/${_KERNEL_VERSION}/build

    mkdir install
    mv * install
    for i in `find install -name "*.ko" `; do strip --strip-unneeded $i; done
    tar zcvf install.tgz install
    md5sum install.tgz > install.tgz.md5
    rm -rf install
    cd ${DIR}
}

function print_usage() {
  echo 'Usage:
  ./build.sh [OPTION]'
  echo 'Options:
  rt : build realtime kernel only
  nonrt : build non realtime kernel only
  clean: clean build and install dir, but keep ESD files that you may have copied
  cleanall: clean build and install dir including copied ESD files (if any)
  help: prints this menu
  version: current commit and date
  '
}

function version() {
  commit=$(git log -1 --pretty=%H)
  date=$(git log -1 --pretty=%cd)
  echo "Commit: $commit"
  echo "Date: $date"
  echo "Version: $_KERNEL_VERSION"
}

case $1 in
  rt)
    kernel_patch
    prepare_rt
    kernel_build
    ;;
  nonrt)
    kernel_patch
    prepare_nonrt
    kernel_build
    ;;
  clean)
    kernel_clean
    ;;
  cleanall)
    kernel_cleanall
    ;;
  version)
    version
    ;;
  help)
    print_usage
    ;;
  *)
    kernel_patch
    prepare_nonrt
    kernel_build
    prepare_rt
    kernel_build
    ;;
esac
