#!/bin/sh

set -eu

TARGET_ARMBIAN="${1:-Jammy_current}"
SECTOR_SIZE=512
BOOT_START=2048
IMG=odroid-hc4.img
# In MB
BOOT_SIZE=128
BOOT_SECTORS=$(( $BOOT_SIZE*1024*1024 / $SECTOR_SIZE ))
STARTUP_MNTPOINT="/mnt"
ROOT_MNTPOINT="/tmp/odroid"

cleanup() {
	set +e
	sudo umount "$STARTUP_MNTPOINT"
	sudo umount "$ROOT_MNTPOINT"

	losetup -a | grep "odroid" | awk '{print $1}' | sed 's/://' |
		while read DEV; do
			sudo losetup -d "$DEV"
		done
	rm -f "$TARGET_ARMBIAN"
	set -e
}

get_armbian() {
	if ! test -f "$1"; then
		wget -O "$1.xz" -c "https://redirect.armbian.com/region/EU/odroidhc4/$1" 
		xz -d "$1.xz"
	fi
}

get_startup() {
	sudo mkdir -p "$STARTUP_MNTPOINT"
	START=$(fdisk -l "$1" | grep "^$1" | awk '{print $2}')

	sudo mount -o "offset=$(( $START * 512 ))" "$1" "$STARTUP_MNTPOINT"
	# Copy Kernel, DTB and ramdisk
	for T in dtb uImage uInitrd ; do
		cp -Lr "$STARTUP_MNTPOINT/boot/$T" .
	done
	# Inject update-bootloader
	cp -rav zz-update-boot-images "$STARTUP_MNTPOINT"/etc/kernel/postinst.d/zz-update-boot-images
	chmod u+x "$STARTUP_MNTPOINT"/etc/kernel/postinst.d/zz-update-boot-images
	# Inject fancontrol
	cp -rav fancontrol "$STARTUP_MNTPOINT"/etc/fancontrol
	sudo umount "$STARTUP_MNTPOINT"
}

partsize() {
	T="$1"
	sfdisk --dump "$T" | grep "^$T" | awk '{print $6}' | sed 's/,//'
}

find_device() {
	IMG="$1"

	losetup --json |
		jq -r ".loopdevices[] | select(.[\"back-file\"] |strings | test(\"$IMG\")).name"
}

mount_and_run_loop() {
	OFFSET="$1"
	UMOUNT="$2"
	shift 2

	sudo losetup -P -o "$OFFSET"  -f "$IMG"
	sleep 1

	DEV="$(find_device "$IMG")"

	$@ "$DEV"

	if "$UMOUNT"; then
		sudo losetup -d "$DEV"
		sleep 1
	fi
}

trap cleanup EXIT

# Start by cleaning the environment
cleanup

get_armbian "$TARGET_ARMBIAN"
get_startup "$TARGET_ARMBIAN"

mkdir -p "$ROOT_MNTPOINT"

truncate -s 0 "$IMG"
PSIZE=$(( $BOOT_START * $SECTOR_SIZE ))
PSIZE=$(( $PSIZE + $BOOT_SECTORS ))
PSIZE=$(( $PSIZE + $(partsize "$TARGET_ARMBIAN") ))
dd if=/dev/zero count=0 seek=$PSIZE bs=$SECTOR_SIZE of="$IMG"

sfdisk "$IMG" <<-_END_
label: dos
label-id: 0x03823826
device: mmc
unit: sectors
sector-size: $SECTOR_SIZE

mmc1 : start=$BOOT_START, size=$BOOT_SECTORS, type=c
mmc2 : start=$(( $BOOT_START + $BOOT_SECTORS )), size=$(partsize "$TARGET_ARMBIAN"), type=83
_END_

mount_and_run_loop "$(( $BOOT_START * $SECTOR_SIZE ))" \
	true \
       	sudo mkfs.fat -F 32

# Add the original partition to the new one
START=$(( $BOOT_START + $BOOT_SECTORS ))
dd if="$TARGET_ARMBIAN" of="$IMG" seek=$START skip=8192 bs=$SECTOR_SIZE

# XXX use mount_and_run_loop
sudo losetup -P -o "$(( $BOOT_START * $SECTOR_SIZE ))" -f "$IMG"
sleep 1

# head -1 is the workaround to get only the last one
DEV="$(find_device "$IMG" | head -1)"

sleep 1
sudo mount "$DEV" "$ROOT_MNTPOINT"

# Chainload Linux Bootloader
sudo cp -r boot.ini config.ini "$ROOT_MNTPOINT/"
sudo cp -r uImage uInitrd dtb "$ROOT_MNTPOINT/"

sudo umount "$ROOT_MNTPOINT"

echo "[+] DONE"
