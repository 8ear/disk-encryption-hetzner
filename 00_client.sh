#!/bin/bash
# Contribution to: 
# https://unix.stackexchange.com/questions/411945/luks-ssh-unlock-strange-behaviour-invalid-authorized-keys-file
# https://projectgus.com/2013/05/encrypted-rootfs-over-ssh-with-debian-wheezy/

echo "Please give me the Hostname of your server"
read HOSTNAME
echo "Please give me the IP of your server"
read IP

# Generate SSH Key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/hetzner_unlock
ssh-keygen -t rsa -b 4096 -f ~/.ssh/hetzner_login

echo "
Host unlock_$HOSTNAME
	User root
	Hostname $IP
  HostKeyAlias unlock_$HOSTNAME
  Port 22
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/hetzner_unlock

Host rescue_$HOSTNAME
	User root
	Hostname $IP
  HostKeyAlias rescue_$HOSTNAME
  Port 22
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/hetzner_login

Host $HOSTNAME
	User root
	Hostname $IP
	HostKeyAlias hetzner_$HOSTNAME
  Port 22
	PreferredAuthentications publickey
  IdentityFile ~/.ssh/hetzner_login " >> ~/.ssh/config

# Test connection
ssh rescue_${HOSTNAME} -v
