![](https://github.com/asineth0/checkn1x/blob/master/icon_dark.png?raw=true)

# checkn1x

Linux-based distribution for jailbreaking iOS devices w/ checkra1n.

## Downloads

Downloads are available under [releases](https://github.com/asineth0/checkn1x/releases).

## Usage

**Use whatever tool you want, but I'm only officially supporting Etcher.**

1. Download [Etcher](https://etcher.io) and the ISO from releases.
2. Open the ``.iso`` you downloaded in Etcher.
3. Write it to your USB drive.
4. Reboot and enter your BIOS's boot menu.
5. Select the USB drive.

## Building

* The ``CRSOURCE`` variable is the direct link to the build of checkra1n that will be used.
* Add something to the ``VERSION`` variable if you want to redistribute your image, i.e. ``1.0.6-foo``.

```sh
# debian/ubuntu/mint/etc.
apt install curl ca-certificates tar gzip grub2-common grub-pc-bin grub-efi-amd64-bin

# archlinux
pacman -S --needed curl tar gzip grub mtools xorriso cpio xz

sudo ./build.sh
```
