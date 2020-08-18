#!/bin/bash
#
# checkn1x build script
# https://asineth.gq/checkn1x
#
VERSION="1.0.8"
CRSOURCE="https://assets.checkra.in/downloads/linux/cli/x86_64/607faa865e90e72834fce04468ae4f5119971b310ecf246128e3126db49e3d4f/checkra1n"

umount work/chroot/dev > /dev/null 2>&1
umount work/chroot/sys > /dev/null 2>&1
umount work/chroot/proc > /dev/null 2>&1
rm -rf work
mkdir -p work/chroot
mkdir -p work/iso/boot/grub

curl -sL "http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.0-x86_64.tar.gz" | tar -xzC work/chroot

mount -o bind /dev work/chroot/dev
mount -t sysfs sysfs work/chroot/sys
mount -t proc proc work/chroot/proc
cp /etc/resolv.conf work/chroot/etc

cat << ! > work/chroot/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

cat << ! | chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
apk upgrade
apk add alpine-base ncurses-terminfo-base udev usbmuxd
apk add --no-scripts linux-lts linux-firmware-none
rc-update add bootmisc
rc-update add hwdrivers
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

cat << ! > work/chroot/etc/mkinitfs/features.d/checkn1x.modules
kernel/drivers/gpu
kernel/drivers/i2c
kernel/drivers/video
kernel/arch/x86/video/fbdev.ko
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
!
chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
	/sbin/mkinitfs -F "checkn1x" -k -t /tmp -q $(ls work/chroot/lib/modules)

umount work/chroot/dev
umount work/chroot/sys
umount work/chroot/proc
rm -f work/chroot/etc/resolv.conf

rm -rf work/chroot/lib/modules
mv work/chroot/tmp/lib/modules work/chroot/lib
find work/chroot/lib/modules/* -type f -name "*.ko" -exec strip --strip-unneeded {} \;
find work/chroot/lib/modules/* -type f -name "*.ko" -exec xz -v -T 0 -9 {} \;
depmod -b work/chroot $(ls work/chroot/lib/modules)
rm -rf work/chroot/tmp
rm -rf work/chroot/var

ln -s ../../etc/terminfo work/chroot/usr/share/terminfo
curl -sLo work/chroot/sbin/checkra1n "$CRSOURCE"
chmod +x work/chroot/sbin/checkra1n

cat << ! > work/chroot/init
#!/bin/sh
exec /sbin/init
!
chmod +x work/chroot/init

sed -i 's/getty 38400 tty1/checkra1n/' work/chroot/etc/inittab

cp work/chroot/boot/vmlinuz-lts work/iso/boot/vmlinuz
rm -rf work/chroot/boot

cat << ! > work/iso/boot/grub/grub.cfg
insmod all_video
echo 'checkn1x $VERSION :: https://asineth.gq'
linux /boot/vmlinuz quiet loglevel=3
initrd /boot/initramfs.xz
boot
!

cd work/chroot
find . | cpio -oH newc | xz -z -C crc32 --x86 -9 -e -T 0 > ../iso/boot/initramfs.xz

grub-mkrescue --compress=xz --fonts= --locales= --themes= --modules= -o ../checkn1x-$VERSION.iso ../iso
