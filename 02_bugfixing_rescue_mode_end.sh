#!/bin/bash

update-initramfs -u
update-grub
exit

umount /mnt/var/ /mnt/backup /mnt/boot /mnt/dev /mnt/sys /mnt/proc
umount /mnt/

vgchange -a n vg0

cryptsetup luksClose crypt


reboot
