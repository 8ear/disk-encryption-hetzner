#!/bin/bash

# - install busybox and dropbear
apt update && apt install busybox dropbear openssh-server
# - Edit your `/etc/initramfs-tools/initramfs.conf` and set `BUSYBOX=y`
sed -i ',s,BUSYBOX=auto,BUSYBOX=y,g' /etc/initramfs-tools/initramfs.conf
#
echo "now create your ssh key on client"
echo "ready?"
read input
echo "now scp your ssh public key to /root/.ssh/id_rsa.pub"
read input
# - `mkdir -p /etc/initramfs-tools/root/.ssh/`
mkdir -p /etc/initramfs-tools/root/.ssh/
 /etc/initramfs-tools/root/.ssh/authorized_keys
sh -c "cat id_rsa.pub >> /etc/initramfs-tools/root/.ssh/authorized_keys"
echo "have you the rescue mode activated?
read input
reboot
