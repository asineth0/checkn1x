#!/bin/bash
#
# checkn1x build script
# https://asineth.gq/checkn1x
#

SCRIPT_IS_CALLED_WITH_ARCH_ENV=$CHECKN1X_ARCH
VERSION="1.1.5"
# Download links
x86_64_ROOTFS="http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.1-x86_64.tar.gz"
x86_64_CRBINARY="https://assets.checkra.in/downloads/linux/cli/x86_64/4bf2f7e1dd201eda7d6220350db666f507d6f70e07845b772926083a8a96cd2b/checkra1n"
i486_ROOTFS="http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86/alpine-minirootfs-3.12.1-x86.tar.gz"
i486_CRBINARY="https://assets.checkra.in/downloads/linux/cli/i486/7926a90f4d0b73bdc514bd813e1443e4fc579e1674e34622b4bd1002a3322e0f/checkra1n"
# Set variables accroding to target arch
if [ "$CHECKN1X_ARCH" == '' ]
then
	CHECKN1X_ARCH="x86_64"
fi
if [ "$CHECKN1X_ARCH" == "x86_64" ]; then
	ROOTFS=$x86_64_ROOTFS
	CRBINARY=$x86_64_CRBINARY
elif [ "$CHECKN1X_ARCH" == "i486" ]; then
	ROOTFS=$i486_ROOTFS
	CRBINARY=$i486_CRBINARY
else
	echo "Unsupported arch: "$CHECKN1X_ARCH
fi
# clean up previous attempts
umount -v work/rootfs/dev >/dev/null 2>&1
umount -v work/rootfs/sys >/dev/null 2>&1
umount -v work/rootfs/proc >/dev/null 2>&1
if [ "$SCRIPT_IS_CALLED_WITH_ARCH_ENV" == "" ]; then
rm -rf out
fi
rm -rf work
mkdir -pv work/{rootfs,iso/boot/grub}
mkdir -pv out
cd work

# fetch rootfs
curl -sL "$ROOTFS" | tar -xzC rootfs
mount -vo bind /dev rootfs/dev
mount -vt sysfs sysfs rootfs/sys
mount -vt proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc
cat <<! >rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

# rootfs packages & services
cat <<! | chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
apk upgrade
apk add xz alpine-base ncurses-terminfo-base udev usbmuxd openssh-client sshpass usbutils
apk add --no-scripts linux-lts linux-firmware-none
rc-update add bootmisc
rc-update add hwdrivers
rc-update add networking
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

# kernel modules
cat <<! >rootfs/etc/mkinitfs/features.d/checkn1x.modules
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
!
chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
	/sbin/mkinitfs -F "checkn1x" -k -t /tmp -q $(ls rootfs/lib/modules)
rm -rfv rootfs/lib/modules
mv -v rootfs/tmp/lib/modules rootfs/lib
find rootfs/lib/modules/* -type f -name "*.ko" | xargs -n1 -P$(nproc) -- strip -v --strip-unneeded
find rootfs/lib/modules/* -type f -name "*.ko" | xargs -n1 -P$(nproc) -- xz --x86 -v9eT0
depmod -b rootfs $(ls rootfs/lib/modules)

# unmount fs
umount -v rootfs/dev
umount -v rootfs/sys
umount -v rootfs/proc

# fetch resources
curl -Lo rootfs/usr/local/bin/checkra1n "$CRBINARY"
mkdir -pv rootfs/opt/odysseyra1n && pushd $_
curl -L -O https://github.com/coolstar/odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/bootstrap_1700.tar.gz \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/migration \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/org.coolstar.sileo_2.0.0b6_iphoneos-arm.deb \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
find . -type f -name '*.gz' | xargs -n1 -P`nproc` -- gzip -vd
tar -vc * | xz --arm -zvce9T 0 > odysseyra1n_resources.tar.xz
popd

# copy files
cp -av ../inittab rootfs/etc
cp -av ../scripts/* rootfs/usr/local/bin
chmod -v 755 rootfs/usr/local/bin/*
ln -sv sbin/init rootfs/init
ln -sv ../../etc/terminfo rootfs/usr/share/terminfo # fix ncurses
echo 'auto lo' >rootfs/etc/network/interfaces       # fix 127.0.0.1

# boot config
cp -av rootfs/boot/vmlinuz-lts iso/boot/vmlinuz
cat <<! >iso/boot/grub/grub.cfg
insmod all_video
echo 'checkn1x $VERSION : https://asineth.gq'
echo 'If you are stuck at here, try using etcher to write the .iso to USB instead. (Rufus in ISO mode does NOT work!)'
linux /boot/vmlinuz quiet loglevel=3
initrd /boot/initramfs.xz
boot
!

# initramfs
pushd rootfs
rm -rfv tmp/*
rm -rfv boot/*
rm -rfv var/cache/*
rm -fv etc/resolv.conf
rm -rf etc/apk lib/apk sbin/apk
rm -rfv opt/odysseyra1n/*.deb 
rm -rfv opt/odysseyra1n/*.tar 
rm -rfv opt/odysseyra1n/migration
find . | cpio -oH newc | xz -C crc32 --x86 -vz9eT0 > ../iso/boot/initramfs.xz
popd

# iso creation
GRUB_MODS="linux all_video configfile echo part_gpt part_msdos"
grub-mkrescue -o "../out/checkn1x-$VERSION-$CHECKN1X_ARCH.iso" iso \
	--compress=xz \
	--fonts= \
	--install-modules="$GRUB_MODS" \
	--modules="$GRUB_MODS" \
	--locales= \
	--themes=
# build 32 bit
if [ "$SCRIPT_IS_CALLED_WITH_ARCH_ENV" == "" ]; then
    cd ..
	CHECKN1X_ARCH=i486 exec ./build.sh
fi
