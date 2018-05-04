Hetzner Dedicated Root Full Disk Encryption withou Private Key on Server for Debian Stretch Minimal 
====

# Reqirements
For this guide you need the following requirements:
- dedicated hetzner root server
- small knowhow about Linux

**This Guide is only for debian Stretch minimal**
# Purpose of the guide is a full disk encryption on a Hetzner dedicated root server
####################


########################################################
# Rescue System
########################################################
Login to your Hetzner Rescue System and install your Image.
```bash
installimage
```
-------------------------------------------------------------------

  Welcome to the Hetzner Rescue System.

  This Rescue System is based on Debian 8.0 (jessie) with a newer
  kernel. You can install software as in a normal system.

  To install a new operating system from one of our prebuilt
  images, run 'installimage' and follow the instructions.

  More information at http://wiki.hetzner.de

-------------------------------------------------------------------


         Intel(R) PRO/1000 Network Driver


fdisk /dev/sda -l

`Disk /dev/sda: 2.7 TiB, 3000034656256 bytes, 5859442688 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 2266476B-2A79-4F71-A886-2D8D417EB3DB

Device       Start        End    Sectors  Size Type
/dev/sda1     4096    4198399    4194304    2G Linux filesystem
/dev/sda2  4198400 5859442654 5855244255  2.7T Linux LVM
/dev/sda3     2048       4095       2048    1M BIOS boot

Partition table entries are not in disk order.`


mkdir /oldroot
vgchange -a y
mount /dev/vg0/root /mnt/
mount /dev/vg0/var /mnt/var
mount /dev/vg0/ /mnt/var
rsync -a /mnt/ /oldroot/
umount /mnt/var
umount /mnt/
vgchange -a n

cryptsetup --cipher aes-xts-plain64 -s 512 --iter-time 5000 luksFormat /dev/sda2
cryptsetup luksOpen /dev/sda2 cryptroot
pvcreate /dev/mapper/cryptroot 
vgcreate vg0 /dev/mapper/cryptroot 
lvcreate -n swap -L +10G vg0
lvcreate -n root -L +50G vg0
lvcreate -n var -L +100G vg0
vgchange -a y vg0
mkfs.ext4 /dev/vg0/root 
mkfs.ext4 /dev/vg0/var
mkswap /dev/vg0/swap 
tune2fs -i 6m -e remount-ro -c 50 /dev/vg0/root 
tune2fs -i 6m -e remount-ro -c 50 /dev/vg0/var
mount /dev/vg0/root /mnt/
mkdir /mnt/var
mount /dev/vg0/var /mnt/var
rsync -a /oldroot/ /mnt/
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mount --bind /dev /mnt/dev/
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc
chroot /mnt/

########################################################
# Chroot in Live Systems
########################################################
apt update && apt install busybox cryptsetup dropbear-initramfs
echo "$(while read m _; do /sbin/modinfo -F filename "$m"; done </proc/modules |sed -nr "s@^/lib/modules/`uname -r`/kernel/drivers/net(/.*)?/([^/]+)\.ko\$@\2@p")" >> /etc/initramfs-tools/modules
echo -e "if you have an intel nic, you should see the following: e1000e \n $(cat /etc/initramfs-tools/modules) "

echo -e "cryptroot \t /dev/sda2 \t none \t luks" >> /etc/crypttab 
sed -i /s/lvmetad = 1/lvmetad = 0/g/ /etc/lvm/lvm.conf 
echo "/sbin/ifdown --force enp4s0" >> /etc/rc.local
echo "/sbin/ifup --force enp4s0" >> /etc/rc.local
echo "# Please paste in your public ssh key to unlocking the server and save wit ':wq':" >> /etc/dropbear-initramfs/authorized_keys
vi /etc/dropbear-initramfs/authorized_keys 
update-initramfs -u -k all
update-grub
grub-install /dev/sda
exit
 
 
########################################################
# Rescue System
########################################################
umount /mnt/boot
umount /mnt/proc
umount /mnt/sys
umount /mnt/dev
umount /mnt/var
umount /mnt
vgchange -a n
cryptsetup luksClose cryptroot
reboot