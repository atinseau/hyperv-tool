#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

echo "Add alias in  shell..."

#if shell is zsh
new_alias="alias dk='docker kill \$(docker ps --format \"{{.Names}}\")'"

if [ -f "$USER_HOME/.zshrc" ]; then
  echo $new_alias >> $USER_HOME/.zshrc
  chown $SSH_USER:$SSH_USER $USER_HOME/.zshrc
fi

#if shell is bash
if [ -f "$USER_HOME/.bashrc" ]; then
  echo $new_alias >> $USER_HOME/.bash_aliases
  chown $SSH_USER:$SSH_USER $USER_HOME/.bash_aliases
fi

echo "Alias docker kill added"