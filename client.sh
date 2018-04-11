#!/bin/bash
# Contribution 2: https://unix.stackexchange.com/questions/411945/luks-ssh-unlock-strange-behaviour-invalid-authorized-keys-file
# https://projectgus.com/2013/05/encrypted-rootfs-over-ssh-with-debian-wheezy/

echo "Please give me the Hostname of your server"
read HOSTNAME
echo "Please give me the IP of your server"
read IP

# Generate SSH Key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/unlock_$HOSTNAME
# Copy SSH Key
scp .ssh/unlock_$HOSTNAME.pub root@$IP:/root/.ssh/unlock_$HOSTNAME.pub


echo -e "Host $HOSTNAME_unlock
  User root
  Hostname $IP
  # The next line is useful to avoid ssh conflict with IP
  HostKeyAlias $HOSTNAME_luks_unlock
  Port 22
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/unlock_$HOSTNAME" >> ~/.ssh/config

# Test connection
ssh $HOSTNAME_unlock -v
