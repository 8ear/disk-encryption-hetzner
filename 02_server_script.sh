#!/bin/bash

### Rescue image the second

mkdir /oldroot
mount /dev/vg0/root /mnt
mount /dev/vg0/backup /mnt/backup
mount /dev/vg0/var /mnt/var

rsync -a /mnt/ /oldroot/

umount /mnt/var /mnt/backup
umount /mnt

echo "Backup your old vg0 configuration to keep things simple and remove the old volume group"
vgcfgbackup vg0 -f vg0.freespace
vgremove vg0

# After this, we encrypt our raid 1 now.
#- `cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 6000 luksFormat /dev/md1`
cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 6000 luksFormat /dev/sda2
#(!!!Choose a strong passphrase (something like `pwgen 64 1`)!!!)
#- `cryptsetup luksOpen /dev/md1 cryptroot`
cryptsetup luksOpen /dev/sda2 crypt
#- now create the physical volume on your mapper:
#- `pvcreate /dev/mapper/cryptroot`
pvcreate /dev/mapper/cryptroot

#We have now to edit your vg0 backup:
#- `blkid /dev/mapper/cryptroot`
blkid /dev/mapper/crypt
# Results in:  `/dev/mapper/cryptroot: UUID="HEZqC9-zqfG-HTFC-PK1b-Qd2I-YxVa-QJt7xQ"`
echo "please copy the blkid into a texteditor you need it later"
read input


#- `cp vg0.freespace /etc/lvm/backup/vg`
cp vg0.freespace /etc/lvm/backup/vg

# Now edit the `id` (UUID from above) and `device` (/dev/mapper/cryptroot) property in the file according to our installation
#- `vi /etc/lvm/backup/vg0`
echo "now you edit as next step the vg0 backup for the restore you need to replace the blkid and device path of the 'pv' only"
read input
vi /etc/lvm/backup/vg0
#- Restore the vgconfig: 
vgcfgrestore vg0
vgchange -a y vg0

#Ok, the filesystem is missing, lets create it:
mkfs.btrs /dev/vg0/root
mkfs.xfs /dev/vg0/backup
mkfs.xfs /dev/vg0/var
mkswap /dev/vg0/swap

# Now we mount and copy our installation back on the new lvs:
mount /dev/vg0/root /mnt/
mkdir /mnt/var /mnt/backup
mount /dev/vg0/var /mnt/var/
mount /dev/vg0/backup /mnt/backup
rsync -a /oldroot/ /mnt/

### Some changes to your existing linux installation
#Lets mount some special filesystems for chroot usage:
mount /dev/sda1 /mnt/boot
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc

# To let the system know there is a new crypto device we need to edit the cryptab(/etc/crypttab):
echo "crypt /dev/sda2 none luks" >> /mnt/etc/crypttab`

chroot /mnt
# Regenerate the initramfs:
update-initramfs -u
update-grub
grub-install /dev/sda


# To be sure the network interface is coming up:
echo "/sbin/ifdown --force enp" >> /etc/rc.local
echo "/sbin/ifup --force eth0" >> /etc/rc.local


# Time for our first reboot.. fingers crossed!
exit`
umount /mnt/boot /mnt/backup /mnt/var /mnt/proc /mnt/sys /mnt/dev
umount /mnt
vgchange -a n
cryptsetup luksClose crypt
sync
reboot
