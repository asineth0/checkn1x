#!/bin/bash
#
# checkn1x build script
# https://asineth.gq/checkn1x
#
VERSION="1.1.0"
ROOTFS="http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.0-x86_64.tar.gz"
CRBINARY="https://assets.checkra.in/downloads/linux/cli/x86_64/607faa865e90e72834fce04468ae4f5119971b310ecf246128e3126db49e3d4f/checkra1n"

umount rootfs/dev > /dev/null 2>&1
umount rootfs/sys > /dev/null 2>&1
umount rootfs/proc > /dev/null 2>&1
rm -rf work
mkdir -p work/rootfs work/iso/boot/grub
cd work

curl -sL "$ROOTFS" | tar -xzC rootfs

mount -o bind /dev rootfs/dev
mount -t sysfs sysfs rootfs/sys
mount -t proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc

cat << ! > rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

cat << ! | chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
apk upgrade
apk add alpine-base ncurses-terminfo-base udev usbmuxd
apk add --no-scripts linux-lts linux-firmware-none
rc-update add bootmisc
rc-update add hwdrivers
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

cat << ! > rootfs/etc/mkinitfs/features.d/checkn1x.modules
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
!
chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
	/sbin/mkinitfs -F "checkn1x" -k -t /tmp -q $(ls rootfs/lib/modules)

umount rootfs/dev
umount rootfs/sys
umount rootfs/proc
rm -f rootfs/etc/resolv.conf

rm -rf rootfs/lib/modules
mv rootfs/tmp/lib/modules rootfs/lib
find rootfs/lib/modules/* -type f -name "*.ko" -exec strip --strip-unneeded {} \;
find rootfs/lib/modules/* -type f -name "*.ko" -exec xz -v -T 0 -9 {} \;
depmod -b rootfs $(ls rootfs/lib/modules)

ln -s ../../etc/terminfo rootfs/usr/share/terminfo
curl -sLo rootfs/usr/bin/checkra1n "$CRBINARY"
chmod 755 rootfs/usr/bin/checkra1n

cp ../inittab rootfs/etc
ln -s sbin/init rootfs/init

cp rootfs/boot/vmlinuz-lts iso/boot/vmlinuz
cat << ! > iso/boot/grub/grub.cfg
insmod all_video
linux /boot/vmlinuz quiet loglevel=3
initrd /boot/initramfs.xz
boot
!

cd rootfs
rm -rfv tmp/*
rm -rfv var/cache/*
rm -rfv boot/*
find . | cpio -oH newc | xz -z -C crc32 --x86 -9 -e -T 0 > ../iso/boot/initramfs.xz
cd ..

grub-mkrescue -o "checkn1x-$VERSION.iso" iso \
	--compress=xz \
	--fonts= \
	--install-modules="linux all_video configfile" \
	--modules="linux all_video configfile" \
	--locales= \
	--themes= \
	--verbose
