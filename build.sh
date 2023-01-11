#!/usr/bin/env bash
#
# checkn1x build script
# https://asineth.me/checkn1x
#
VERSION="1.1.8"
ROOTFS="https://dl-cdn.alpinelinux.org/alpine/v3.14/releases/x86_64/alpine-minirootfs-3.14.8-x86_64.tar.gz"
CRBINARY="https://assets.checkra.in/downloads/linux/cli/x86_64/dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d/checkra1n"

if [[ $EUID -ne 0 ]]; then
	echo "$0: This script must be run with sudo or as su. Exiting."
	exit 1
fi

# clean up previous attempts
umount -v work/rootfs/{dev,sys,proc} >/dev/null 2>&1
rm -rf work
mkdir -pv work/{rootfs,iso/boot/grub}
cd work

# fetch rootfs
curl -sL "$ROOTFS" | tar -xzC rootfs
mount -vo bind /dev rootfs/dev
mount -vt sysfs sysfs rootfs/sys
mount -vt proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc
cat << ! > rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/v3.13/main
http://dl-cdn.alpinelinux.org/alpine/v3.13/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

# rootfs packages & services
cat << ! | chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
apk upgrade
apk add alpine-base ncurses-terminfo-base udev usbmuxd libusbmuxd-progs openssh-client sshpass usbutils
apk add --no-scripts linux-lts linux-firmware-none
rc-update add bootmisc
rc-update add hwdrivers
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

# kernel modules
cat << ! > rootfs/etc/mkinitfs/features.d/checkn1x.modules
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
kernel/net/ipv4
!
chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
	/sbin/mkinitfs -F "checkn1x" -k -t /tmp -q $(ls rootfs/lib/modules)
rm -rfv rootfs/lib/modules
mv -v rootfs/tmp/lib/modules rootfs/lib
find rootfs/lib/modules/* -type f -name "*.ko" -exec strip -v --strip-unneeded {} \; -exec xz --x86 -v9eT0 \;
depmod -b rootfs $(ls rootfs/lib/modules)

# unmount fs
umount -v rootfs/{dev,sys,proc}

# fetch resources
curl -Lo rootfs/usr/local/bin/checkra1n "$CRBINARY"

# copy files
cp -av ../inittab rootfs/etc
cp -av ../scripts/* rootfs/usr/local/bin
chmod -v 755 rootfs/usr/local/bin/*
ln -sv sbin/init rootfs/init
ln -sv ../../etc/terminfo rootfs/usr/share/terminfo # fix ncurses

# boot config
cp -av rootfs/boot/vmlinuz-lts iso/boot/vmlinuz
cat << ! > iso/boot/grub/grub.cfg
insmod all_video
echo 'checkn1x $VERSION : https://asineth.me'
linux /boot/vmlinuz quiet loglevel=3
initrd /boot/initramfs.xz
boot
!

# initramfs
pushd rootfs
rm -rfv tmp/* boot/* var/cache/* etc/resolv.conf
find . | cpio -oH newc | xz -C crc32 --x86 -vz9eT$(nproc --all) > ../iso/boot/initramfs.xz
popd

# iso creation
grub-mkrescue -o "checkn1x-$VERSION.iso" iso --compress=xz
