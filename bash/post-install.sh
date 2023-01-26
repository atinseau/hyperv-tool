#!/bin/bash

# if installed file exists, return
if [ -f "$HOME/.installed" ]; then
    echo "Already installed"
    exit 0
fi

sudo -S apt update -y && sudo -S apt upgrade -y

# GLOBAL PACKAGES

sudo -S apt install -y \
    linux-virtual \
    linux-cloud-tools-virtual \
    linux-tools-virtual \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    cifs-utils


# DOCKER INSTALL

sudo -S mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo -S gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo -S tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo -S apt update -y 
sudo -S apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo -S curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo -S chmod +x /usr/local/bin/docker-compose

sudo -S groupadd docker
sudo -S usermod -aG docker $USER
echo "Docker installed"

# FSTAB

echo "Configurate windows share ? (y/n)"
read answer

if [[ "$answer" == "y" ]]; then
mkdir "$HOME/share"
cat <<EOF > $HOME/.cifscredentials
username=$WINDOWS_USERNAME
password=$WINDOWS_PASSWORD
domain=groupe.lan
EOF

echo "//$WINDOWS_IP/share $HOME/share cifs credentials=$HOME/.cifscredentials,uid=1000,gid=1000,vers=3.0,iocharset=utf8 0 0" | sudo -S tee -a /etc/fstab
fi



# NVM INSTALL

curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -SE bash -
sudo -S apt install -y nodejs
sudo -S npm install -g yarn


echo "installed" > $HOME/.installed

sudo reboot


