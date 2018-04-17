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
    IdentityFile ~/.ssh/<UNLOCKIDENTFILE>

Host rescue_<NAME>
	User root
	Hostname <IP>
    HostKeyAlias rescue_<NAME>
    Port 22
    PreferredAuthentications publickey
    IdentityFile ~/.ssh/<IDENTFILE>

Host <NAME>
	User root
	Hostname <IP>
	HostKeyAlias hetzner_<NAME>
    Port 22
	PreferredAuthentications publickey
    IdentityFile ~/.ssh/<IDENTFILE>" >> ~/.ssh/config

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

## First steps in rescue image

- Boot to the rescue system via hetzners server management page
- install a minimal Debian Stretch (e.g. 9.4) with hetzners "installimage" skript (https://wiki.hetzner.de/index.php/Installimage)
- choose the following logical volumes on system or modifiy the tasks later on your own setup:

```
PART 
lv-swap (10GB) swap
lv-root (all) -> means remaining space ext4
lv-root (all) -> means remaining space ext4
```

- after you adjusted all parameters in the install config file, press F10 to install the ubuntu minimal system
- reboot and ssh into your fresh installed ubuntu




# Start Server
## Unlock Server
After a few seconds the dropbear ssh server is coming up on your system, connect to it and unlock your system like this:

- a busybox shell should come up
- unlock your lvm drive with:
```bash
ssh -i .ssh/unlock_dropbear root@<yourserverip>
echo -ne "<yourstrongpassphrase>" > /lib/cryptsetup/passfifo
```

## Login to Server

```bash
ssh -i .ssh/dropbear root@<yourserverip>
```


# Sources:
Special thanks to the people who wrote already this guides:

- http://notes.sudo.is/RemoteDiskEncryption
- https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system
- https://kiza.eu/journal/entry/697
- 

# Contribution

- PRs are very welcome or open an issue if something not works for you as described
