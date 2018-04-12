#!/bin/bash

umount /mnt/var/ /mnt/backup /mnt/boot /mnt/dev /mnt/sys /mnt/proc
umount /mnt/

vgchange -a n vg0

cryptsetup luksClose crypt
