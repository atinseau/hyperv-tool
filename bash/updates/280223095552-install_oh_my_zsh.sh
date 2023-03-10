#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

echo "Installing oh my zsh..."

apt-get install -y zsh

function setup_oh_my_zsh () {(
  git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
  cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
  cat <<EOF >> $HOME/.zshrc
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh" # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
  chsh -s $(which zsh)
)}

export -f setup_oh_my_zsh

su $SSH_USER --shell /bin/bash -c "setup_oh_my_zsh"

if [ $? -ne 0 ]; then
  echo "Error while setting up oh my zsh"
  exit 1
fi

echo "Oh my zsh installed"