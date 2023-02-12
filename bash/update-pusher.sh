#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

if ! apt list --installed 2> /dev/null | grep jq > /dev/null; then
  echo "Installing jq..."
  apt install -y jq > /dev/null
fi

for f in /tmp/updates/*.sh; do
  echo "Processing $f"
  bash $f $USER_HOME $SSH_USER $VM_IP $HOST_IP
  exit_code=$?
  bool="true"
  if [ $exit_code -ne 0 ]; then
    bool="false"
  fi

  IN="$f"
  arrIN=(${IN//-/ })
  id=$(echo ${arrIN[0]} | sed 's/\/tmp\/updates\///g')

  cat $USER_HOME/.installed | jq ". += {\"$id\": $bool}" > $USER_HOME/.installed.tmp
  mv $USER_HOME/.installed.tmp $USER_HOME/.installed
  chown $SSH_USER:$SSH_USER $USER_HOME/.installed

  if [ "$bool" = "false" ]; then
    echo "Error while processing $f"
    exit 1
  fi
done

rm -rf /tmp/updates

