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
ssh-keygen -t ecdsa  -f ~/.ssh/hetzner_rescue
ls la ~/.ssh
```

This generates the following output with `ls la ~/.ssh`:
- hetzner_unlock
- hetzner_unlock.pub
- hetzner_login
- hetzner_login.pub
- hetzner_rescue
- hetzner_rescue.pub

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
    IdentityFile ~/.ssh/hetzner_rescue

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
1. Activate Hetzner Rescue Mode
```
## Setup Server for Disk Encrpytion | Second steps in rescure image

# Next, fill the named rootfs partition with pseudo-random data. This will take a little over a half an hour to complete.
dd if=/dev/urandom of=/dev/sda3 bs=1M status=progress

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

# After this, we encrypt
##for software raid: use `/dev/md1` instead of `/dev/sda3`
cryptsetup luksFormat /dev/sda3 -c serpent-xts-plain64 -h whirlpool -s 512
##(!!!Choose a strong passphrase (something like `pwgen 64 1`)!!!)

```
1. Activate VNC Installer for CentOS 7.9 and restart
2. Login via VNC Client to the proposed IP and port and with the shown password
3. Install CentOS with encrypted volume group with custom partiotioning like described in https://www.vultr.com/docs/install-and-setup-centos-7-to-remotely-unlock-lvm-on-luks-disk-encryption-using-ssh
  - Partitions scheme:
   - Biosboot 2M
   - /boot ext2 512M
   - LUKS Encrypted
     - root 10G
     - var/log 20G
     - var/lib/docker xG
     - swap 8G
     - /backup | /nsm | ...
4. If finished Activate Hetzner rescue system on Hetzner Robot
5. Click Reboot on VNC screen
6. Login to hetzner Rescue system
7. Resize sda3 to full size: `cgdisk /dev/sda`
 - Remove sda3
 - Add additional partition with full size, partition code was used on my setup: 0700 whyever
7. Open luks disk: `cryptsetup luksOpen /dev/sda3 crypt # OR for software raid: cryptsetup luksOpen /dev/md1 crypt`
8. Resize pv: `pvresize /dev/mapper/crypt`
9. Copy things from script below...

```bash
# Mount:
mount /dev/vg0/root /mnt
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc

# Change chroot environment
chroot /mnt

# mount all other
mount -a -v

# Update system, install base things
sudo yum -y install vim wget git bash-completion epel-release nano sudo fail2ban
sudo wget -O /etc/yum.repos.d/rbu-dracut-crypt-ssh-epel-7.repo https://copr.fedorainfracloud.org/coprs/rbu/dracut-crypt-ssh/repo/epel-7/rbu-dracut-crypt-ssh-epel-7.repo
sudo yum -y install dracut-crypt-ssh

# Update grub config
# more help: https://github.com/dracut-crypt-ssh/dracut-crypt-ssh
## Insert rd.neednet=1 ip=<IP>::<Gatewa<>:<subnet>:<cryptodevicename>:enp0s8:off between GRUB_CMDLINE_LINUX="crashkernel=auto and rd.luks.uuid=luks-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
sudo nano /etc/default/grub
## Regenerate you GRUB configuration file by type the command below.
sudo grub2-mkconfig -o /etc/grub2.cfg 

# Backup the original /etc/dracut.conf.d/crypt-ssh.conf by typing the following command below.
sudo mv /etc/dracut.conf.d/crypt-ssh.conf /etc/dracut.conf.d/crypt-ssh.conf.orig

# Create a new /etc/dracut.conf.d/crypt-ssh.conf file by typing the following command below.
echo 'dropbear_acl="/etc/dropbear/keys/authorized_keys"' >> /etc/dracut.conf.d/crypt-ssh.conf
echo 'dropbear_ecdsa_key="/etc/dropbear/keys/ssh_ecdsa_key"' >> /etc/dracut.conf.d/crypt-ssh.conf
echo 'dropbear_rsa_key="/etc/dropbear/keys/ssh_rsa_key"' >> /etc/dracut.conf.d/crypt-ssh.conf
# You can also choose any other port
echo 'dropbear_port="222"' >> /etc/dracut.conf.d/crypt-ssh.conf
cat /etc/dracut.conf.d/crypt-ssh.conf
sudo mkdir /etc/dropbear/keys/;
```
Generate ECDSA key: `sudo ssh-keygen -t ecdsa -f /etc/dropbear/keys/ssh_ecdsa_key -C dropbear@luks`
Generate RSA key: `sudo ssh-keygen -t rsa -b 4096 -f /etc/dropbear/keys/ssh_rsa_key -C dropbear@luks`

```bash
sudo chmod 400 /etc/dropbear/keys/*_key; sudo chmod 444 /etc/dropbear/keys/*.pub

# Add authorized SSH key
sudo nano /etc/dropbear/keys/authorized_keys

# Update dracut
sudo dracut -f -v

# SSH settings for user
su <user>
```
Add user ssh key: `ssh-keygen -t ecdsa -C <user>@<hostname>`
```
# Add your user SSH pub key
vi ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
restorecon -r ~/.ssh/
exit

# Update System
sudo yum update -y && sudo yum clean all

# umount
umount -a -v

# leave chroot environment
exit

# umount all
umount /mnt/dev
umount /mnt/sys
umount /mnt/proc
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
`console_auth`
add your unlock password.

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
- https://mirrors.edge.kernel.org/pub/linux/utils/boot/dracut/dracut.html#_network
- https://phoenixnap.com/kb/how-to-enable-ssh-centos-7
- https://github.com/dracut-crypt-ssh/dracut-crypt-ssh
- https://geekpeek.net/disk-encryption-on-centos-linux/
- https://phoenixnap.com/kb/configure-centos-network-settings

# Thanks
Special thanks to [TheReal1604](https://github.com/TheReal1604) from github.com.

# Contribution
PRs are very welcome or open an issue if something not works for you as described
