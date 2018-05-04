#!/bin/bash

installimage


# please look into README for the Volumes!!!


##########################################
#
# Execute this script after installation of Debian Stratch minimal IN RESCUE MODE
#

mount /dev/vg0/root /mnt
mount /dev/vg0/backup /mnt/backup
mount /dev/vg0/var /mnt/var
mount /dev/vg0/log /mnt/var/log
mount /dev/sda1 /mnt/boot
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc

# To let the system know there is a new crypto device we need to edit the cryptab(/etc/crypttab):
echo "crypt /dev/sda2 none luks" >> /mnt/etc/crypttab


chroot /mnt

# - install busybox and dropbear
apt update && apt install -y busybox dropbear openssh-server cryptsetup lvm2 python
# Python package for Ansible enabled
# - Edit your `/etc/initramfs-tools/initramfs.conf` and set `BUSYBOX=y`
sed -i 's/BUSYBOX=auto/BUSYBOX=y/g' /etc/initramfs-tools/initramfs.conf
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf
#
echo "now create your ssh key on client"
echo "ready?"
read input
echo "now scp your ssh public key to /root/.ssh/id_rsa.pub"
read input
nano /etc/dropbear-initramfs/authorized_keys

# Regenerate the initramfs:
update-initramfs -u
update-grub
grub-install /dev/sda

# To be sure the network interface is coming up:
echo "/sbin/ifdown --force enp" >> /etc/rc.local
echo "/sbin/ifup --force eth0" >> /etc/rc.local

############################################################################################
# manual:
exit
###########################
mkdir /oldroot

umount /mnt/boot
umount /mnt/dev
umount /mnt/sys
umount /mnt/proc

rsync -a /mnt/ /oldroot/

umount /mnt/backup
umount /mnt/var/log
umount /mnt/var
umount /mnt


#Backup your old vg0 configuration to keep things simple and remove the old volume group
vgcfgbackup vg0 -f vg0.freespace
vgchange -a n
vgremove vg0

# After this, we encrypt our raid 1 now.
#- `cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 6000 luksFormat /dev/md1`
cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 6000 luksFormat /dev/sda2
#(!!!Choose a strong passphrase (something like `pwgen 64 1`)!!!)

cryptsetup luksOpen /dev/sda2 crypt
pvcreate /dev/mapper/crypt
cp vg0.freespace /etc/lvm/backup/vg0

# Now edit the `id` (UUID from above) and `device` (/dev/mapper/cryptroot) property in the file according to our installation
echo "now you edit as next step the vg0 backup for the restore you need to replace the blkid and device path of the 'pv' only with:"
echo "id: `blkid /dev/mapper/crypt`"
echo "device: blkid /dev/mapper/crypt"
read input
vi /etc/lvm/backup/vg0
#- Restore the vgconfig: 
vgcfgrestore vg0
vgchange -a y vg0

#Ok, the filesystem is missing, lets create it:
mkfs.ext4 /dev/vg0/root
mkfs.xfs /dev/vg0/backup
mkfs.ext4 /dev/vg0/var
mkfs.ext4 /dev/vg0/log
mkswap /dev/vg0/swap

# Now we mount and copy our installation back on the encrypted LVM:
mount /dev/vg0/root /mnt/
mkdir -p /mnt/var/log /mnt/backup
mount /dev/vg0/var /mnt/var/
mount /dev/vg0/log /mnt/var/log
mount /dev/vg0/backup /mnt/backup
rsync -a /oldroot/ /mnt/

# Now ready for reboot
umount /mnt/backup 
umount /mnt/var/log 
umount /mnt/var
umount /mnt
vgchange -a n
cryptsetup luksClose crypt
sync
reboot
###########################################