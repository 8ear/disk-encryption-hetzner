## CentOS disk-encryption-hetzner for SecurityOnion2

This should be a clean step-by-step guide how to setup a hetzner root server from the server auctions at hetzners "serverbörse" to get a fully encrypted software raid1 with lvm on top.

The goal of this guide is to have a server system that has encrypted drives and is remotely unlockable.

This guide *could* work at any other provider with a rescue system.


# Client Configuration

## Generate SSH Keys
```bash
ls la ~/.ssh
ssh-keygen -t ecdsa  -f ~/.ssh/hetzner_unlock
ssh-keygen -t ecdsa  -f ~/.ssh/hetzner_login
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

`vi install-config.txt`
```
#DRIVE1 /dev/nvme0n1
#DRIVE2 /dev/nvme1n1
#SWRAID 1
#SWRAIDLEVEL 0 # Use 1 for Raid 1

DRIVE1 /dev/sda
BOOTLOADER grub
HOSTNAME <myhostname>
PART /boot ext3 512M
PART lvm vg0 all

LV vg0 tmp /tmp ext4 2G
LV vg0 swap swap    swap    8G
LV vg0 root /       ext4    10G
LV vg0 var-log  /var/log ext4   20G
LV vg0 var-lib-docker  /var/lib/docker    ext4    100G
LV vg0 backup /backup ext4  100G
LV vg0 nsm /nsm ext4 200G

# Please check the path first!!!
IMAGE /root/.oldroot/nfs/install/../images/CentOS-78-64-minimal.tar.gz # CentOS-82-64-minimal.tar.gz for CentOS 8

```
   `The Sizes can be modified later, but better customize it to your requirements yet.`
   I create a own `var` partition because docker, vmware workstation and proxmox create her images, volumes and container in a subfolder of `var`:
   * /var/lib/docker
   * /var/lib/vmware
   * /var/lib/vz or /var/lib/pve

   Additionally there is also the log directory:
   * /var/log
   Additionaly there is also the backup directory:
   * /backup   
   Additionaly there is also the securityonion2 nsm directory:
   * /nsm

   I want to prevent that my root partition is full, because a image required to much space or a logifle is to big.''



4. Install it...
`installimage -a -c install-config.txt`
   


## Setup Server for Disk Encrpytion | Second steps in rescure image
1. Execute this script after installation of CentOS7 minimal IN RESCUE MODE.

```bash
# Mount all:
mount /dev/vg0/root /mnt
mount /dev/vg0/backup /mnt/backup
mount /dev/vg0/var-lib-docker /mnt/var/lib/docker
mount /dev/vg0/var-log /mnt/var/log
mount /dev/vg0/nsm /mnt/nsm
mount /dev/sda1 /mnt/boot  # OR for software raid: mount /dev/md0 /mnt/boot

# Create backup directory
mkdir /oldroot

# sync all to backup directory
rsync -av /mnt/ /oldroot/

# umount all other after backup
umount /mnt/boot
umount /mnt/backup
umount /mnt/nsm
umount /mnt/var/log
umount /mnt/var/lib/docker
umount /mnt

# deactivate volume group
vgchange -a n

#Recreate partitions
parted -a opt -s /dev/sda mklabel gpt
parted -s /dev/sda unit mb
parted -s /dev/sda mkpart primary 1 3
parted -s /dev/sda name 1 grub
parted -s /dev/sda set 1 bios_grub on
parted -s /dev/sda mkpart primary 3 520
parted -s /dev/sda name 2 boot
parted -s /dev/sda mkpart primary 520 100%
parted -s /dev/sda name 3 root
parted -s /dev/sda print

# Next, fill the named rootfs partition with pseudo-random data. This will take a little over a half an hour to complete.
dd if=/dev/urandom of=/dev/sda3 bs=1M status=progress

# After this, we encrypt
##for software raid: use `/dev/md1` instead of `/dev/sda3`
cryptsetup luksFormat /dev/sda3 -c serpent-xts-plain64 -h whirlpool -s 512
##(!!!Choose a strong passphrase (something like `pwgen 64 1`)!!!)

# Open luks
cryptsetup luksOpen /dev/sda3 crypt # OR for software raid: cryptsetup luksOpen /dev/md1 crypt

# Create LVM
pvcreate /dev/mapper/crypt
vgcreate vg0 /dev/mapper/crypt
lvcreate -n swap -l 8G vg0
lvcreate -n root -l 10G vg0
lvcreate -n var-log -l 20G vg0
lvcreate -n var-lib-docker -l 100G vg0
lvcreate -n nsm -l 300G vg0

# Format LVMs
mkfs.ext4 /dev/mapper/vg0-nsm
mkfs.ext4 /dev/mapper/vg0-var-lib-docker
mkfs.ext4 /dev/mapper/vg0-var-log
mkfs.ext4 /dev/mapper/vg0-root
mkswap /dev/mapper/vg0-swap

# Mount all:
mount /dev/vg0/root /mnt
#mount /dev/vg0/backup /mnt/backup
mount /dev/vg0/var-lib-docker /mnt/var/lib/docker
mount /dev/vg0/var-log /mnt/var/log
mount /dev/vg0/nsm /mnt/nsm
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc
mount /dev/sda1 /mnt/boot  # OR for software raid: mount /dev/md0 /mnt/boot

# restore files
rsync -av /oldroot/ /mnt/

# Change chroot environment
chroot /mnt

# Update system, install base things
sudo yum -y install vim wget git bash-completion epel-release nano sudo
sudo wget -O /etc/yum.repos.d/rbu-dracut-crypt-ssh-epel-7.repo https://copr.fedorainfracloud.org/coprs/rbu/dracut-crypt-ssh/repo/epel-7/rbu-dracut-crypt-ssh-epel-7.repo
sudo yum -y install dracut-crypt-ssh

# Update grub config
## Insert rd.neednet=1 ip=dhcp between GRUB_CMDLINE_LINUX="crashkernel=auto and rd.luks.uuid=luks-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
sudo nano /etc/default/grub
## Regenerate you GRUB configuration file by type the command below.
sudo grub2-mkconfig -o /etc/grub2.cfg 

# Backup the original /etc/dracut.conf.d/crypt-ssh.conf by typing the following command below.
sudo mv /etc/dracut.conf.d/crypt-ssh.conf /etc/dracut.conf.d/crypt-ssh.conf.orig

# Create a new /etc/dracut.conf.d/crypt-ssh.conf file by typing the following command below.
echo 'dropbear_acl="/etc/dropbear/keys/authorized_keys"' >> /etc/dracut.conf.d/crypt-ssh.conf
echo 'dropbear_ecdsa_key="/etc/dropbear/keys/ssh_ecdsa_key"' >> /etc/dracut.conf.d/crypt-ssh.conf
echo 'dropbear_rsa_key="/etc/dropbear/keys/ssh_rsa_key"' >> /etc/dracut.conf.d/crypt-ssh.conf
sudo mkdir /etc/dropbear/keys/; sudo chmod /etc/dropbear/keys/
sudo ssh-keygen -t ecdsa -f /etc/dropbear/keys/ssh_ecdsa_key
sudo ssh-keygen -t rsa -b 4096 -f /etc/dropbear/keys/ssh_rsa_key
sudo chmod 400 /etc/dropbear/keys/*_key; sudo chmod 444 /etc/dropbear/keys/*.pub

# Add authorized SSH key
sudo nano /etc/dropbear/keys/authorized_keys

# Update dracut
sudo dracut -f

# Update System
sudo yum clean all && sudo yum update -y

# To let the system know there is a new crypto device we need to edit the cryptab(/etc/crypttab):
echo "crypt /dev/sda2 none luks" >> /mnt/etc/crypttab # or for software raid: echo "crypt /dev/md1 none luks" >> /mnt/etc/crypttab

# leave chroot environment
exit

# umount all
umount /mnt/boot
umount /mnt/nsm
umount /mnt/var/log
umount /mnt/var/lib/docker
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
- https://computingforgeeks.com/how-to-install-centos-7-on-hetzner-root-servers/
- https://www.vultr.com/docs/install-and-setup-centos-7-to-remotely-unlock-lvm-on-luks-disk-encryption-using-ssh

# Thanks
Special thanks to [TheReal1604](https://github.com/TheReal1604) from github.com.

# Contribution
PRs are very welcome or open an issue if something not works for you as described
