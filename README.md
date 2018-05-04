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
Host unlock_<NAME>
	User root
	Hostname <IP>
    HostKeyAlias unlock_<NAME>
    Port 22
    PreferredAuthentications publickey
    IdentityFile ~/.ssh/hetzner_unlock

Host rescue_<NAME>
	User root
	Hostname <IP>
    HostKeyAlias rescue_<NAME>
    Port 22
    PreferredAuthentications publickey
    IdentityFile ~/.ssh/hetzner_login

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
# For System:
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
5. reboot and ssh into your fresh installed ubuntu 
    * [UNTESTED] -> perhaps this steps can be skipped

## Setup debian minimal server 

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
