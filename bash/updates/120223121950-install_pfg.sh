#!/bin/bash


USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

echo "Installing pfg..."

# Recreate pfg folder
rm -rf $USER_HOME/pfg-v3
mkdir -p $USER_HOME/pfg-v3
chown $SSH_USER:$SSH_USER $USER_HOME/pfg-v3

cd $USER_HOME/pfg-v3

# Checking if ssh config file exists and fix it
cat $USER_HOME/.ssh/config | grep "StrictHostKeyChecking no" > /dev/null
if [ $? -ne 0 ]; then
  echo "Host *" >> $USER_HOME/.ssh/config
  echo " StrictHostKeyChecking no" >> $USER_HOME/.ssh/config
  chown $SSH_USER:$SSH_USER $USER_HOME/.ssh/config
fi


# Clone pfg
su $SSH_USER --shell /bin/bash -c "git clone internet-drupal-ogf@vs-ssh.visualstudio.com:v3/internet-drupal-ogf/SITE%20INTERNET%20PFG/Site-PFG-front" && \
su $SSH_USER --shell /bin/bash -c "git clone internet-drupal-ogf@vs-ssh.visualstudio.com:v3/internet-drupal-ogf/SITE%20INTERNET%20PFG/Site-PFG-back"

# Check if clone was successful
if [ $? -ne 0 ]; then
  echo "Error while cloning pfg"
  echo "Maybe you need to add your ssh key to your account on https://internet-drupal-ogf.visualstudio.com/_usersSettings/keys"
  
  if [ ! -f "$USER_HOME/.ssh/id_rsa.pub" ]; then
    su $SSH_USER --shell /bin/bash -c "ssh-keygen -t rsa -f $USER_HOME/.ssh/id_rsa -q -P \"\""
  fi

  echo "--------------------------------"
  cat $USER_HOME/.ssh/id_rsa.pub
  echo "--------------------------------"

  exit 1
fi

# Set permissions
chown -R $SSH_USER:$SSH_USER $USER_HOME/pfg-v3

# setup pfg front with right permissions
function setup_front () {(

  cd $HOME/pfg-v3/Site-PFG-front

  export NVM_DIR=$HOME/.nvm;
  source $NVM_DIR/nvm.sh;

  git checkout develop
  pnpm install
)}

function setup_back () {(
  cd $HOME/pfg-v3/Site-PFG-back

  git checkout develop
  docker login registry.gitlab.com/ogf-digital/ogf-deploiement/pfg_drupal:devops-registry -u arthur.tinseau.ogf -p 06112001..Arttsn
  chmod +x run.sh
  ./run.sh

  # user should drag and drop the database in the share folder
  read -p "Drag and drop the database in the share folder and press enter to continue (pfg.sql)"

  if [ ! -f "$HOME/share/pfg.sql" ]; then
    echo "pfg.sql not found in share folder"
    exit 1
  fi

  cp $HOME/share/pfg.sql ./src/.
  docker exec -it pfg_back_local_drupal /bin/bash -c "composer install"
  docker exec -it pfg_back_local_drupal /bin/bash -c "drush sql-cli < pfg.sql"
  docker exec -it pfg_back_local_drupal /bin/bash -c "bash scripts/update.sh"
  
)}

export -f setup_front
export -f setup_back

su $SSH_USER --shell /bin/bash -c "setup_front"
if [ $? -ne 0 ]; then
  echo "Error while setting up pfg"
  exit 1
fi

cat /etc/hosts | grep "pfg.front.local.fr" > /dev/null
if [ $? -ne 0 ]; then
  echo "127.0.0.1 pfg.front.local.fr" >> /etc/hosts
fi


# remounting share folder
mount -a
su $SSH_USER --shell /bin/bash -c "setup_back"
if [ $? -ne 0 ]; then
  echo "Error while setting up pfg"
  exit 1
fi

cat /etc/hosts | grep "pfg.back.local.fr" > /dev/null
if [ $? -ne 0 ]; then
  echo "127.0.0.1 pfg.back.local.fr" >> /etc/hosts
  echo "127.0.0.1 media-pfg.back.local.fr" >> /etc/hosts
fi


echo "pfg installed"
echo "Maybe you need to add in your windows hosts file the following lines:"
echo "--------------------------------"
echo "$VM_IP pfg.front.local.fr"
echo "$VM_IP pfg.back.local.fr"
echo "$VM_IP media-pfg.back.local.fr"
echo "--------------------------------"