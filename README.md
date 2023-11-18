# Build Armbian for Odroid HC4

## What does this project do?

All the project is about to get Armbian (Tested on version Jammy-current) on Odroid HC4 without erase petitboot partition on your board.

Otherwise you shall wipe your SPI boot partition and erase the default bootloader of the board.

### How it works ?

The scripts exploit `jq` to work, you need to install it. For example we tested the script in Debian and so to install the package:
```bash
sudo apt install jq
```

To generate the new target image, simply run the generate-image.sh script as root from within the project folder. For example, you can use the following command: 
```bash
sudo ./generate-image.sh.
```

After that you will have `odroid-hc4.img` file which you just need to write on your SD card, example:

```bash
sudo dd if=odroid-hc4.img of=/dev/mmcblk0 conv=fsync status=progress
```

Remember to change `/dev/mmcblk0` with the correct target device!
