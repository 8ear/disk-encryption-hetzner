#!/bin/bash

cryptsetup luksOpen /dev/sda2 crypt
vgchange -a y vg0

# Now we mount and copy our installation back on the new lvs:
mount /dev/vg0/root /mnt/
mount /dev/vg0/var /mnt/var/
mount /dev/vg0/backup /mnt/backup
mount /dev/sda1 /mnt/boot
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc
chroot /mnt
