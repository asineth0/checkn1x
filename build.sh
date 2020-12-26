#!/bin/bash
#
# checkn1x build script
# https://asineth.gq/checkn1x
#
VERSION="1.1.5-odysseyra1n"
ROOTFS="http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86/alpine-minirootfs-3.12.1-x86.tar.gz"
CRBINARY="https://assets.checkra.in/downloads/linux/cli/i486/7ea7cc69d58308e2e96bc9f40f63f4f135d3b8fafd49a1bb4f4a849876f49fdb/checkra1n"
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
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

# rootfs packages & services
cat << ! | chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
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
cat << ! > rootfs/etc/mkinitfs/features.d/checkn1x.modules
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
curl -L -O https://github.com/coolstar/odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/bootstrap_1700.tar.gz \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/migration \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/org.coolstar.sileo_2.0.0b6_iphoneos-arm.deb \
-O https://github.com/coolstar/odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
find . -type f -name '*.gz' | xargs -n1 -P`nproc` -- gzip -vd
tar -vc * | xz -zvce9T 0 --arm > odysseyra1n_resources.tar.xz
popd

# copy files
cp -av ../inittab rootfs/etc
cp -av ../scripts/* rootfs/usr/local/bin
chmod -v 755 rootfs/usr/local/bin/*
ln -sv sbin/init rootfs/init
ln -sv ../../etc/terminfo rootfs/usr/share/terminfo # fix ncurses
echo 'auto lo' > rootfs/etc/network/interfaces # fix 127.0.0.1

# boot config
cp -av rootfs/boot/vmlinuz-lts iso/boot/vmlinuz
cat << ! > iso/boot/grub/grub.cfg
insmod all_video
echo 'checkn1x $VERSION : https://asineth.gq'
echo 'checkn1x32 repository: https://github.com/Assfugil/checkn1x32'
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
rm -rfv opt/odysseyra1n/*.deb 
rm -rfv opt/odysseyra1n/*.tar 
rm -rfv opt/odysseyra1n/migration
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
	--themes= \
	--verbose
