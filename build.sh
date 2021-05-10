#!/bin/bash
#
# checkn1x build script
# https://asineth.gq/checkn1x
#
VERSION="1.1.6"
ROOTFS="https://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.3-x86_64.tar.gz"
CRBINARY="https://assets.checkra.in/downloads/linux/cli/x86_64/845bd19fb857e5546ba312e768ab42e8aeab7a34470b07f60a9892e92fe8273e/checkra1n"

# clean up previous attempts
umount -v work/rootfs/dev >/dev/null 2>&1
umount -v work/rootfs/sys >/dev/null 2>&1
umount -v work/rootfs/proc >/dev/null 2>&1
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
http://dl-cdn.alpinelinux.org/alpine/v3.12/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
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
find rootfs/lib/modules/* -type f -name "*.ko" | xargs -n1 -P`nproc` -- strip -v --strip-unneeded
find rootfs/lib/modules/* -type f -name "*.ko" | xargs -n1 -P`nproc` -- xz --x86 -v9eT0
depmod -b rootfs $(ls rootfs/lib/modules)

# unmount fs
umount -v rootfs/dev
umount -v rootfs/sys
umount -v rootfs/proc

# fetch resources
curl -Lo rootfs/usr/local/bin/checkra1n "$CRBINARY"
mkdir -pv rootfs/opt/odysseyra1n && pushd $_
curl -LO 'https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz' \
	-O 'https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz' \
	-O 'https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.coolstar.sileo_2.0.0b6_iphoneos-arm.deb' \
	-O 'https://github.com/coolstar/Odyssey-bootstrap/raw/master/migration'
find . -type f -name '*.gz' | xargs -n1 -P`nproc` -- gzip -vd
find . -type f -name '*.tar' | xargs -n1 -P`nproc` -- xz -v --arm -9 -e -T0
popd

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
echo 'checkn1x $VERSION : https://asineth.gq'
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
find . | cpio -oH newc | xz -C crc32 --x86 -vz9eT0 > ../iso/boot/initramfs.xz
popd

# iso creation
GRUB_MODS="linux all_video configfile echo part_gpt part_msdos"
grub-mkrescue -o "checkn1x-$VERSION.iso" iso \
	--compress=xz \
	--fonts= \
	--install-modules="$GRUB_MODS" \
	--modules="$GRUB_MODS" \
	--locales= \
	--themes=
