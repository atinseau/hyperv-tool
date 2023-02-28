#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

# Fixing ssh config file
rm -f $USER_HOME/.ssh/config
touch $USER_HOME/.ssh/config

# Checking if ssh config file exists and fix it
cat $USER_HOME/.ssh/config | grep "StrictHostKeyChecking no" > /dev/null
if [ $? -ne 0 ]; then
  echo "Host *" >> $USER_HOME/.ssh/config
  echo " StrictHostKeyChecking no" >> $USER_HOME/.ssh/config
  echo " ServerAliveInterval 600" >> $USER_HOME/.ssh/config
  echo " TCPKeepAlive yes" >> $USER_HOME/.ssh/config
  echo " IPQoS=throughput" >> $USER_HOME/.ssh/config
  chown $SSH_USER:$SSH_USER $USER_HOME/.ssh/config
fi

echo "Ssh config file fixed..."