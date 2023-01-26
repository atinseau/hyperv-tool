#!/bin/bash

# if installed file exists, return
if [ -f "$HOME/.installed" ]; then
    echo "Already installed"
    exit 0
fi

# MOVING CONF FILES
sed -i "s/<IP>/$VM_IP/g" /tmp/00-installer-config.yaml
sudo -S mv /tmp/00-installer-config.yaml /etc/netplan/00-installer-config.yaml

sed -i "s/<USER>/$WINDOWS_USERNAME/g" /tmp/ogf-proxy.sh
sed -i "s/<PASSWORD>/$WINDOWS_PASSWORD/g" /tmp/ogf-proxy.sh
mv /tmp/ogf-proxy.sh /home/$USER/ogf-proxy.sh

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
mkdir "$HOME/share"
cat <<EOF > $HOME/.cifscredentials
username=$WINDOWS_USERNAME
password=$WINDOWS_PASSWORD
domain=groupe.lan
EOF
echo "//$WINDOWS_IP/share $HOME/share cifs credentials=$HOME/.cifscredentials,uid=1000,gid=1000,vers=3.0,iocharset=utf8 0 0" | sudo -S tee -a /etc/fstab



# NVM INSTALL

curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -SE bash -
sudo -S apt install -y nodejs
sudo -S npm install -g yarn

echo "installed" > $HOME/.installed

chmod +x $HOME/ogf-proxy.sh
$HOME/ogf-proxy.sh




