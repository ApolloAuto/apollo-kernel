# Install NVIDIA driver on Ubuntu 18.04
If you want to install Apollo-Kernel on Ubuntu 18.04, please follow the steps below to install Apollo-Kernel and NVIDIA driver.

## Install Apollo Kernel
Follow the steps in [Apollo Software Installation Guide](https://github.com/ApolloAuto/apollo/tree/master/docs/quickstart/apollo_software_installation_guide.md#Install-apollo-kernel)to install Apollo Kernel.


## Install gcc 4.8 and set default gcc

```
sudo apt install gcc-4.8 gcc-4.8-multilib g++-4.8 g++-4.8-multilib   gcc gcc-multilib g++ g++-multilib  cmake autoconf automake
sudo /usr/bin/update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 99 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
gcc -v   # check gcc version
```

Reboot the system with Apollo Kernel

## Install nvidia driver

```
sudo bash -x install-nvidia.sh
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt-get update
sudo apt-get install nvidia-driver-430
```

Reboot the system with Apollo Kernel

## Restore default gcc 7

```
sudo /usr/bin/update-alternatives --remove gcc /usr/bin/gcc-4.8
sudo /usr/bin/update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 99 --slave /usr/bin/g++ g++ /usr/bin/g++-7
```
