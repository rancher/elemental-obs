#!/bin/bash -x

: ${TOPDIR:=/usr/src/packages}

container="buildcont"

set -e

echo "Looking for an ISO image ..."

# Only run the post build check for aarch64
[ "$(uname -m)" == "aarch64" ] || exit 0

# Build service provides the container image as a .tar file

img=$(ls ${TOPDIR}/DOCKER/*.tar) || true

# Only consider images with 'iso' as part of the name
echo "${img}" | grep -q iso || exit 0

[ -f "${img}" ] || exit 1

echo "Found image '" ${img} "'"

# import .tar with buildah

buildah from --name "${container}"  "docker-archive:${img}"

# mount container to access its content

mnt=$(buildah mount "${container}")

# there must be an .iso file within

iso=$(ls "${mnt}"/elemental-iso/*.iso)

echo "Found ISO '" ${iso} "'"

# exit here if not

[ -f "${iso}" ] || exit 1

# something like sl-micro-6.0-base.aarch64-2.2.0-Build14.2
basename=$(basename ${iso} .iso)
# split at '.' into DOTS[]
IFS='.' read -ra DOTS <<< "${basename}"
# split "0-base" at '-' into DASHES[]
IFS='-' read -ra DASHES <<< "${DOTS[1]}"
# extract the flavor (base, rt, kvm, ...)
flavor="${DASHES[1]}"
# prepend dash if flavor is non-empty
# covers rpi.raw (for empty flavor) vs rpi-${flavor}.raw (for non-empty)
[ -n "$flavor" ] && flavor="-${flavor}"

mkdir -p "${TOPDIR}/OTHER/image"

# create a mountpoint and mount the iso
mkdir iso
mount -o loop "${iso}" iso

# create a mountpoint and mount the rootfs.squashfs that's inside the iso
mkdir rootfs
mount -o loop iso/boot/arm64/loader/rootfs.squashfs rootfs

# extract the image size from the "build config"

img_size=$(grep -m 1 "%img_size" ~/.rpmmacros | tr -d "\n" | cut -d " " -f 2)

# extract two last project path elements ({Stable,Staging,Dev}:TealXX)
# replace colon with dash
project=$(grep -m 1 "%_project" ~/.rpmmacros | tr -d "\n" | rev | cut -d ":" -f 1,2 | rev | tr ":" "-")

# create an empty image file and a respective loop device
truncate -s $((${img_size}*1024*1024)) rpi.img

# create a primary FAT partition with 256MB (for kernel + firmware)
# create a primary Linux partition covering the remainder
sfdisk rpi.img <<EOF
2048,+256M
;
EOF
# FAT32 LBA
sfdisk --part-type rpi.img 1 c
# Linux
sfdisk --part-type rpi.img 2 83
# Activate
sfdisk --activate rpi.img 1

# find first free loop device
loop=`losetup -f`
# connect it to rpi.img, scan partition table
losetup --partscan ${loop} rpi.img

# boot partition
#
mkfs -t vfat -n RPI_BOOT ${loop}p1
# create a mountpoint and mount the FAT partition
mkdir img
mount ${loop}p1 img
# copy EFI binaries
cp --preserve=mode,ownership --recursive --dereference iso/EFI img
# copy kernel, initrd and kernel args
mkdir -p img/boot/arm64/loader
cp --preserve=mode,ownership --dereference iso/boot/arm64/loader/initrd img/boot/arm64/loader
cp --preserve=mode,ownership --dereference iso/boot/arm64/loader/linux img/boot/arm64/loader
cp --preserve=mode,ownership --dereference iso/boot/arm64/loader/bootargs.cfg img/boot/arm64/loader
sed -i "s/=ttyS0 /=ttyS0,115200 /g" img/EFI/BOOT/grub.cfg
# and firmware files to the FAT partition
# 'old' firmware
if [ -d rootfs/boot/vc ]; then
  cp -a rootfs/boot/vc/* img
else
# systemready firmware
  cp rootfs/boot/*.fd img
  cp rootfs/boot/*.dtb img
  cp rootfs/boot/config.txt img
  cp rootfs/boot/fixup4.dat img
  cp rootfs/boot/start4.elf img
  cp -a rootfs/boot/firmware img
  cp -a rootfs/boot/overlays img
fi

umount img

# root partition
#
# label it COS_LIVE
mkfs -t ext3 -L COS_LIVE ${loop}p2
mount ${loop}p2 img
# copy the rootfs into this partition
mkdir -p img/boot/arm64/loader
cp --preserve=mode,ownership --dereference iso/boot/arm64/loader/rootfs.squashfs img/boot/arm64/loader

# Install hook to copy rpi firmware in EFI partition
mkdir -p img/iso-config
if [ -d rootfs/boot/vc ]; then
cat << HOOK > img/iso-config/01_rpi-install-hook.yaml
name: "Raspberry Pi after install hook"
stages:
    after-install:
    - &copyfirmware
      name: "Copy firmware to EFI partition"
      commands:
      - cp -a /run/elemental/workingtree/boot/vc/* /run/elemental/efi
    after-reset:
    - <<: *copyfirmware
HOOK
else
cat << HOOK > img/iso-config/01_rpi-install-hook.yaml
name: "Raspberry Pi after install hook"
stages:
    after-install:
    - &copyfirmware
      name: "Copy firmware to EFI partition"
      commands:
      - cp /run/elemental/workingtree/boot/*.fd /run/elemental/efi
      - cp /run/elemental/workingtree/boot/*.dtb /run/elemental/efi
      - cp /run/elemental/workingtree/boot/config.txt /run/elemental/efi
      - cp /run/elemental/workingtree/boot/fixup4.dat /run/elemental/efi
      - cp /run/elemental/workingtree/boot/start4.elf /run/elemental/efi
      - cp -a /run/elemental/workingtree/boot/firmware /run/elemental/efi
      - cp -a /run/elemental/workingtree/boot/overlays /run/elemental/efi
    after-reset:
    - <<: *copyfirmware
HOOK
fi
# undo all mounts, loopback devices, etc.

umount img
rmdir img
umount rootfs
rmdir rootfs

losetup -d ${loop}
umount iso
rmdir iso

# copy the image as rpi.raw (buildservice checks extensions)

mkdir -p "${TOPDIR}/OTHER"
rawname="rpi${flavor}.raw"
mv rpi.img ${rawname}
sha256sum ${rawname} > "${TOPDIR}/OTHER/${rawname}.sha256"
mv ${rawname} "${TOPDIR}/OTHER"
ln "${TOPDIR}/OTHER/${rawname}" "${TOPDIR}/OTHER/rpi${flavor}-${project}-`date +'%Y%m%d%H%M%S'`.raw"

# release the container

buildah umount "${container}"
buildah rm "${container}"
