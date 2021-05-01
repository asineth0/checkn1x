![](https://github.com/asineth0/checkn1x/blob/master/icon_dark.png?raw=true)

# checkn1x Reborn - bring back Checkn1x with latest Checkra1n version (0.12.3)

Linux-based distribution for jailbreaking iOS devices w/ checkra1n.
Full latest changelogs at [here](https://checkra.in/releases/0.12.3-beta)

## Downloads

Downloads are available under [releases](https://github.com/TeGaX/checkn1x/releases).

## Usage

**Use whatever tool you want, but I'm only officially supporting Etcher.**

1. Download [Etcher](https://etcher.io), [Rufus](https://rufus.ie) and the ISO from releases.
2. Open the ``.iso`` you downloaded in Etcher.
3. Write it to your USB drive.
4. Reboot and enter your BIOS's boot menu.
5. Select the USB drive.

Note: If after writing the ISO to USB but can't boot to Checkn1x, try to write to USB as GPT and DD mode

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

## Credits
2021 @TeGaX @asineth0
