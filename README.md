![](https://git.asineth.gq/asineth/checkn1x/raw/branch/master/icon.png)

# checkn1x

Linux-based distribution for jailbreaking iOS devices w/ checkra1n.

## Downloads

Downloads are available under [releases](https://git.asineth.gq/asineth/checkn1x/releases).

## Usage

1. Download [Etcher](https://etcher.io) and the ISO from releases.
2. Open the ``.iso`` you downloaded in Etcher.
3. Write it to your USB drive.
4. Reboot and enter your BIOS's boot menu.
5. Select the USB drive.

## Building

* Add something to the ``VERSION`` string if you want to redistribute your image, i.e. ``1.0.6-foo``.
* The ``CRSOURCE`` variable is the direct link to the build of checkra1n that will be used.
* You'll need: ``curl``, ``tar``, ``gzip``, and ``grub-mkrescue``.

```sh
# debian/ubuntu/mint/etc.
apt install curl ca-certificates tar gzip grub2-common grub-pc-bin grub-efi-amd64-bin

sudo ./build.sh
```
