#!/bin/bash

vmname=`basename vmlinuz*`
kver=${vmname:8}

if [ -z ${kver} ]; then
echo "failed! kernel version is empty."
exit 0
fi

cp -f vmlinuz* System.map* config* /boot/
[ -d /lib/modules/${kver} ] && rm -rf /lib/modules/${kver}
[ -d /usr/src/linux-headers-${kver} ] && rm -rf /usr/src/linux-headers-${kver}
cp -a modules/* /lib/modules/
cp -a firmware/* /lib/firmware/
[ -d linux-headers-${kver} ] && cp -r linux-headers-${kver} /usr/src/

mkinitramfs -o /boot/initrd.img-${kver} ${kver}

update-grub

sync
