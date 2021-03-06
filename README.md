## disk-encryption-hetzner

This should be a clean step-by-step guide how to setup a hetzner root server from the server auctions at hetzners "serverbörse" to get a fully encrypted software raid1 with lvm on top.

The goal of this guide is to have a server system that has encrypted drives and is remotely unlockable.

This guide *could* work at any other provider with a rescue system.


# Client Configuration

## Generate SSH Keys
```bash
ls la ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/hetzner_unlock
ssh-keygen -t rsa -b 4096 -f ~/.ssh/hetzner_login
ls la ~/.ssh
```

This generates the following output with `ls la ~/.ssh`:
- hetzner_unlock
- hetzner_unlock.pub
- hetzner_login
- hetzner_login.pub


## SSH Config
content of ssh `~/.ssh/config`:
```bash
echo "
# For disk encryption unlock
Host unlock_<NAME>
	User root
	Hostname <IP>
    HostKeyAlias unlock_<NAME>
    Port 22
    PreferredAuthentications publickey
    IdentityFile ~/.ssh/hetzner_unlock

# For Rescure Mode
Host rescue_<NAME>
	User root
	Hostname <IP>
    HostKeyAlias rescue_<NAME>
    Port 22
    IdentityFile ~/.ssh/hetzner_login

# For normal Login
Host <NAME>
	User root
	Hostname <IP>
	HostKeyAlias hetzner_<NAME>
    Port 22
	PreferredAuthentications publickey
    IdentityFile ~/.ssh/hetzner_login " >> ~/.ssh/config

```

## Login to System

```bash
# For rescue System:
ssh rescue_<NAME>

# For unlock the System:
ssh unlock_<NAME>

# For normal login to the System:
ssh <NAME>

```

# Server Configuration

## Install Base Distribution | First steps in rescue image

1. Boot to the rescue system via hetzners server management page
2. install a minimal Debian Stretch (e.g. 9.4) with hetzners [installimage](https://wiki.hetzner.de/index.php/Installimage) script 
3. choose the following logical volumes on system or modifiy the tasks later on your own setup:
 
   ```
   PART /boot ext3 1024M
   PART lvm vg0 all

   LV vg0 swap swap    swap    6G
   LV vg0 root /       ext4    10G
   LV vg0 var  /var    ext4    100G
   LV vg0 log  /var/log ext4   20G
   LV vg0 backup /backup xfs  200G
   ```
   
   `The Sizes can be modified later, but better customize it to your requirements yet.`

   I create a own `var` partition because docker, vmware workstation and proxmox create her images, volumes and container in a subfolder of `var`:
   * /var/lib/docker
   * /var/lib/vmware
   * /var/lib/vz or /var/lib/pve

   Additionally there is also the log directory:
   * /var/log

   I want to prevent that my root partition is full, because a image required to much space or a logifle is to big.''

4. after you adjusted all parameters in the install config file, press F10 to install the ubuntu minimal system

## Setup Server for Disk Encrpytion | Second steps in rescure image
Execute this script after installation of Debian Stretch minimal IN RESCUE MODE.


```bash
# Mount all:
mount /dev/vg0/root /mnt
mount /dev/vg0/backup /mnt/backup
mount /dev/vg0/var /mnt/var
mount /dev/vg0/log /mnt/var/log
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc
mount /dev/sda1 /mnt/boot  # OR for software raid: mount /dev/md0 /mnt/boot

# To let the system know there is a new crypto device we need to edit the cryptab(/etc/crypttab):

echo "crypt /dev/sda2 none luks" >> /mnt/etc/crypttab # or for software raid: echo "crypt /dev/md1 none luks" >> /mnt/etc/crypttab

# Change chroot environment
chroot /mnt

# - install busybox and dropbear
apt update && apt install -y busybox dropbear openssh-server cryptsetup lvm2 python

# Python package for Ansible enabled
# - Edit your `/etc/initramfs-tools/initramfs.conf` and set `BUSYBOX=y`
sed -i 's/BUSYBOX=auto/BUSYBOX=y/g' /etc/initramfs-tools/initramfs.conf
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
# Deactivate lvmetad
sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf


# Copy SSH public keys
echo "now copy your hetzner_unlock ssh public key to /etc/dropbear-initramfs/authorized_keys"
read input
nano /etc/dropbear-initramfs/authorized_keys

echo "now copy your hetzner_login ssh public key to /root/.ssh/id_rsa.pub"
read input
nano /root/authorized_keys


# Regenerate the initramfs:
update-initramfs -u
update-grub
grub-install /dev/sda # and for software raid: grub-install /dev/sdb

# To be sure the network interface is coming up:
echo "/sbin/ifdown --force enp" >> /etc/rc.local
echo "/sbin/ifup --force eth0" >> /etc/rc.local

# leave chroot environment
exit

# Create backup directory
mkdir /oldroot

# umount all what should not be backuped
umount /mnt/boot
umount /mnt/dev
umount /mnt/sys
umount /mnt/proc

# sync all to backup directory
rsync -av /mnt/ /oldroot/

# umount all other after backup
umount /mnt/backup
umount /mnt/var/log
umount /mnt/var
umount /mnt


#Backup your old vg0 configuration to keep things simple and remove the old volume group
vgcfgbackup vg0 -f vg0.freespace
vgchange -a n
vgremove vg0

# After this, we encrypt our raid 1 now.
# for software raid: cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 6000 luksFormat /dev/md1 
cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 6000 luksFormat /dev/sda2
#(!!!Choose a strong passphrase (something like `pwgen 64 1`)!!!)

cryptsetup luksOpen /dev/sda2 crypt # OR for software raid: cryptsetup luksOpen /dev/md1 crypt
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

# I choose ext4 for root and log because its so stable and great. But for the backup and var volume I choose xfs because its easier to resize in live mode and can handle bigger files. You can choose what you want!
#Ok, the filesystem is missing, lets create it:
mkfs.ext4 /dev/vg0/root
mkfs.xfs /dev/vg0/backup
mkfs.xfs /dev/vg0/var
mkfs.ext4 /dev/vg0/log
mkswap /dev/vg0/swap

# Now we mount and copy our installation back on the encrypted LVM:
mount /dev/vg0/root /mnt/
mkdir -p /mnt/var /mnt/backup
mount /dev/vg0/var /mnt/var/
mkdir -p /mnt/var/log
mount /dev/vg0/log /mnt/var/log
mount /dev/vg0/backup /mnt/backup
rsync -av /oldroot/ /mnt/


# umount all
umount /mnt/backup 
umount /mnt/var/log 
umount /mnt/var
umount /mnt
# deactivate volume group
vgchange -a n
# close encrypted disk
cryptsetup luksClose crypt
# sync disks
sync
# Now ready for reboot
reboot
```
Have fun with your new system!

# Start Server
## Unlock Server
After a few seconds the dropbear ssh server is coming up on your system, connect to it and unlock your system like this:

```bash
ssh -i ~/.ssh/hetzner_unlock root@<yourserverip>
# or 
ssh <NAME>_unlock
```
Now unlocking your drive:
```bash
echo -ne "<yourstrongpassphrase>" > /lib/cryptsetup/passfifo
```

## Login to Server

```bash
ssh -i ~/.ssh/hetzner_login root@<yourserverip>
# or
ssh <NAME>
```


# Sources:
Special thanks to the people who wrote already this guides:

- http://notes.sudo.is/RemoteDiskEncryption
- https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system
- https://kiza.eu/journal/entry/697
- https://github.com/TheReal1604/disk-encryption-hetzner

# Thanks
Special thanks to [TheReal1604](https://github.com/TheReal1604) from github.com.

# Contribution
PRs are very welcome or open an issue if something not works for you as described
