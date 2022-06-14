# Build Armbian for Odroid HC4

## What does this project do?

All the project is about to get Armbian Jammy-edge on Odroid HC4 without erase petitboot partition on your board.

### How it works ?

All you need to do is run `generate-image.sh` and you will generate the new target image.

To mount partition you need to be administrator of your machine.

After that you will have odroid-hc4.img file which you just need to write on your SD card, example:

`# dd if=odroid-hc4.img of=/dev/sdX conv=fsync status=progress`
