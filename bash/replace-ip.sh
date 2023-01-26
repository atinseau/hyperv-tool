#!/bin/bash

args=("$@")

oldHostIp=${args[0]}
newHostIp=${args[1]}
oldVmIp=${args[2]}
newVmIp=${args[3]}


sudo -S sed -i "s/${oldHostIp}/${newHostIp}/g" /etc/fstab
echo "  -  [vm:fstab] at /etc/fstab"
sudo -S sed -i "s/${oldHostIp}/${newHostIp}/g" /etc/hosts
echo "  -  [vm:hosts] at /etc/hosts"
sudo -S mount -a
echo "  -  [vm:mount] remounting /home/${USER}/share"