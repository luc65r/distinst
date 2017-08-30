#!/usr/bin/env bash

if [ ! -f "$1" ]
then
    echo "$0 [squashfs]" >&2
    exit 1
fi
SQUASHFS="$(realpath "$1")"

IMAGE=efi.img

set -ex

dd if=/dev/zero of="${IMAGE}" bs=1G count=8
parted -s "${IMAGE}" mklabel gpt
parted -s "${IMAGE}" print
parted -s "${IMAGE}" mkpart primary fat32 0% 256M
parted -s "${IMAGE}" mkpart primary ext4 256M 100%
parted -s "${IMAGE}" print

LO="$(sudo losetup --find --partscan --show "${IMAGE}")"

sudo mkfs.fat -F 32 "${LO}p1"
sudo mkfs.ext4 "${LO}p2"

DIR="$(mktemp -d)"

sudo mount "${LO}p2" "${DIR}/"
sudo mkdir -p "${DIR}/boot/efi"
sudo mount "${LO}p1" "${DIR}/boot/efi"

sudo unsquashfs -f -d "${DIR}/" "$SQUASHFS"

sudo mount --bind /dev "${DIR}/dev"
sudo mount --bind /proc "${DIR}/proc"
sudo mount --bind /sys "${DIR}/sys"

sudo chroot "${DIR}/" apt-get purge -y casper ubiquity
sudo chroot "${DIR}/" apt-get autoremove -y --purge

ROOTDEV="$(sudo chroot "${DIR}/" df --output=source / | sed 1d)"
ROOTUUID="$(sudo chroot "${DIR}/" blkid -o value -s UUID "${ROOTDEV}")"
echo "# / was on ${ROOTDEV} during installation" | sudo chroot "${DIR}/" tee /etc/fstab
echo "UUID=${ROOTUUID} / ext4 errors=remount-ro 0 1" | sudo chroot "${DIR}/" tee -a /etc/fstab

EFIDEV="$(sudo chroot "${DIR}/" df --output=source /boot/efi/ | sed 1d)"
EFIUUID="$(sudo chroot "${DIR}/" blkid -o value -s UUID "${EFIDEV}")"
echo "# /boot/efi was on ${EFIDEV} during installation" | sudo chroot "${DIR}/" tee -a /etc/fstab
echo "UUID=${EFIUUID} /boot/efi vfat umask=0077 0 1" | sudo chroot "${DIR}/" tee -a /etc/fstab

sudo chroot "${DIR}/" locale-gen --purge

sudo chroot "${DIR}/" apt-get install -y xterm grub-efi-amd64-signed

sudo chroot "${DIR}/" grub-mkconfig -o /boot/grub/grub.cfg

sudo grub-install --target=x86_64-efi --boot-directory="${DIR}/boot/" --efi-directory="${DIR}/boot/efi/" "${LO}"

sudo umount "${DIR}/dev"
sudo umount "${DIR}/proc"
sudo umount "${DIR}/sys"

sudo umount "${DIR}" || sudo umount -lf "${DIR}"

rmdir "${DIR}"

sudo losetup -d "${LO}"