#!/bin/sh
#
# checkn1x build script
# https://asineth.gq/checkn1x
#
VERSION="1.0.7"
CRSOURCE="https://assets.checkra.in/downloads/linux/cli/x86_64/607faa865e90e72834fce04468ae4f5119971b310ecf246128e3126db49e3d4f/checkra1n"

set -e -u

rm -rf work
mkdir -p work/chroot
mkdir -p work/iso/boot/grub

curl -L "http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.0-x86_64.tar.gz" | tar -xzC work/chroot

mount -o bind /dev work/chroot/dev
mount -t proc proc work/chroot/proc
mount -t sysfs sysfs work/chroot/sys
cp /etc/resolv.conf work/chroot/etc

cat << ! > work/chroot/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

cat << ! | chroot work/chroot /bin/sh
apk upgrade
apk add alpine-base linux-lts linux-firmware-none udev ncurses-terminfo usbmuxd
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

umount -lf work/chroot/dev
umount -lf work/chroot/sys
umount -lf work/chroot/proc

rm -f work/chroot/etc/resolv.conf
rm -rf work/chroot/var/log/*
rm -rf work/chroot/var/cache/*
rm -rf work/chroot/usr/share/doc/*
rm -rf work/chroot/usr/share/man/*
rm -rf work/chroot/usr/share/info/*
find work/chroot/lib/modules/* -iname '*.ko' | parallel -j$(nproc) xz -9vT1 {}
depmod -b work/chroot $(ls work/chroot/lib/modules)

curl -Lo work/chroot/sbin/checkra1n "$CRSOURCE"
chmod +x work/chroot/sbin/checkra1n

cat << ! > work/chroot/init
#!/bin/sh
exec /sbin/init
!
chmod +x work/chroot/init

sed -i 's/getty 38400 tty1/checkra1n/' work/chroot/etc/inittab

cp work/chroot/boot/vmlinuz-lts work/iso/boot/vmlinuz
rm -rf work/chroot/boot/*

cat << ! > work/iso/boot/grub/grub.cfg
insmod all_video
echo 'checkn1x $VERSION :: https://asineth.gq'
echo 'Loading kernel...'
linux /boot/vmlinuz quiet loglevel=3
echo 'Loading initramfs...'
initrd /boot/initramfs.gz
boot
!

cd work/chroot
find . | cpio -oH newc | pigz -9 > ../iso/boot/initramfs.gz
grub-mkrescue -o ../checkn1x-$VERSION.iso ../iso
