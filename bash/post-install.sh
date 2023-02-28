#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
WINDOWS_IP=$4
WINDOWS_USERNAME=$5
WINDOWS_PASSWORD=$6

if [ -f "$USER_HOME/.installed" ]; then
    echo "Already installed - $USER_HOME/.installed"
    exit 0
fi

echo "session path: $SESSION_PATH"
echo "vm ip: $VM_IP"
echo "windows ip: $WINDOWS_IP"
echo "windows username: $WINDOWS_USERNAME"
echo "windows password: $WINDOWS_PASSWORD"

function install_nvm () {
  echo "Installing nvm..."
  export NVM_DIR="$USER_HOME/.nvm" && (
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1 &> /dev/null) &> /dev/null` 
  ) && \. "$NVM_DIR/nvm.sh"

  cat <<EOF >> $USER_HOME/.bashrc
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh" # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF

  source $USER_HOME/.bashrc
  nvm install --lts
  nvm use --lts
  npm install -g yarn pnpm
}

function install_docker () {
  echo "Installing docker..."
  apt install -y ca-certificates curl gnupg lsb-release
  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  # post-install steps
  groupadd docker
  usermod -aG docker $SSH_USER
}

function install_cifs () {
  echo "Installing cifs..."
  apt install -y cifs-utils
  mkdir -p $USER_HOME/share
  cat <<EOF > $USER_HOME/.cifscredentials
username=$WINDOWS_USERNAME
password=$WINDOWS_PASSWORD
domain=groupe.lan
EOF
  chown $SSH_USER:$SSH_USER $USER_HOME/.cifscredentials
  echo "//$WINDOWS_IP/share $USER_HOME/share cifs credentials=$USER_HOME/.cifscredentials,uid=1000,gid=1000,vers=3.0,iocharset=utf8 0 0" | tee -a /etc/fstab
}

function install_proxy () {
  echo "Installing proxy..."
  sed -i "s/<USER>/$WINDOWS_USERNAME/g" /tmp/ogf-proxy.sh
  sed -i "s/<PASSWORD>/$WINDOWS_PASSWORD/g" /tmp/ogf-proxy.sh
  mv /tmp/ogf-proxy.sh $USER_HOME/ogf-proxy.sh

  touch /etc/apt/apt.conf.d/99verify-peer.conf
  echo "Acquire { https::Verify-Peer false }" | tee /etc/apt/apt.conf.d/99verify-peer.conf > /dev/null
  # mv /tmp/proxy.conf /etc/apt/apt.conf.d/proxy.conf
}

function install_netplan() {
  echo "Installing netplan config..."
  # sed -i "s/<IP>/$VM_IP/g" /tmp/workspace_config.yaml
  # mv /tmp/workspace_config.yaml /etc/netplan/workspace_config.yaml
  rm /etc/netplan/00-installer-config.yaml
  mv /tmp/no_wifi_config.yaml /etc/netplan/00-installer-config.yaml
}

function install_hyperv() {
  echo "Installing hyperv tools..."
  apt install -y "linux-cloud-tools-$(uname -r)"
}

install_nvm
install_cifs
install_proxy
install_docker
install_netplan


echo "{}" > $USER_HOME/.installed
chown $SSH_USER:$SSH_USER $USER_HOME/.installed
echo "Ready to go!"


# preventing stdout interference
install_hyperv