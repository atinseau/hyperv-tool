#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

echo "Installing oh my zsh..."

apt install -y zsh

function setup_oh_my_zsh () {(
  git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
  cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
  chsh -s $(which zsh)
)}

export -f setup_oh_my_zsh

su $SSH_USER -c "setup_oh_my_zsh"


echo "Oh my zsh installed"