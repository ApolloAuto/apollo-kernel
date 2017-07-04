## ESD CAN Driver (Kernel Driver)

In the first release of Apollo software, ESD PCIe CAN is used for CAN communications with the vehicle -- please refer to *Apollo 1.0 Hardware and System Installation Guide* for more information. You MUST obtain ESD CAN driver (kernel module) software from ESD Electronics, and compile it with Apollo Linux kernel to run Apollo software stack.

### How To Add ESD CAN Support

1. After/when you purchase CAN card from ESD Electronics, please contact support@esd.eu to obtain their supporting software package (search for can-pcie/402 to find it on their download website). We have tested version 3.10.3. You may need to make some changes if you use a different version.
2. After unpacking the software package, please copy all files under src/ directory to drivers/esdcan/, except for Makefile.
3. Do the following to prepare for build:
```bash
cd drivers/esdcan/;rm Makefile Kconfig;ln -s Makefile.esd Makefile;ln -s Kconfig.esd Kconfig;cd ../..
```
4. If you have run build.sh to customize your build, you may need to do it again. You can now run "./build.sh [target]" to build the kernel.

### Build ESD Kernel Driver with Pre-Built Apollo Kernel

The ESD CAN driver is not included in the pre-built kernel image release; you can build it after you install the pre-built image, follow the steps below.
1. Download ESD CAN Linux software package from ESD as instructed above.
2. Unpack the package, cd into the package directory; then do the following:
```bash
cd src/; mv Makefile Makefile.orig
```
3. Download Apollo's modified ESD kernel module makefile (path: linux/drivers/esdcan/Makefile.esd), and save Makefile.esd into the src/ directory.
4. Do the following to build the kernel module:
```bash
ln -s Makefile.esd Makefile;make
```
5. The compiled ESD driver is esdcan-pcie402.ko.

### Legal Disclaimer
The kernel image that you build contains the ESD CAN driver module compiled from source code provided by ESD Electronics (hereby referred as ESD) if ESD CAN driver code is added as instructed above. In the process of obtaining the software, you should have entered a licensing agreement with ESD which shall have granted you (as an individual or a business entity) the right to use the said software provided by ESD; however, you may (and likely you do) need explicit re-distribution permission from ESD to publish the kernel image for any other third party to consume. Such licensing agreement is solely between you and ESD, and is not covered by the license terms of the Apollo project (see file LICENSE under Apollo top directory).
