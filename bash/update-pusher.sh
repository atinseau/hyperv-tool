#!/bin/bash

USER_HOME=$1
SSH_USER=$2
VM_IP=$3
HOST_IP=$4

if ! apt-get list --installed 2> /dev/null | grep jq > /dev/null; then
  echo "Installing jq..."
  apt-get install -y jq > /dev/null
fi

updates=($(ls /tmp/updates/*.sh))

# replace all /tmp/updates/ with nothing
updates=(${updates[@]//\/tmp\/updates\//})
# split by - 

updatesJson='{ "updates": [] }'

for i in "${!updates[@]}"; do
  IN="${updates[$i]}"
  arrIN=(${IN//-/ })
  id=$(echo ${arrIN[0]} | sed 's/\/tmp\/updates\///g')
  updatesJson=$(echo $updatesJson | jq '.updates += [{ "hash": '"$id"', "path": '\""${updates[$i]}"\"' }]')
done

updatesJson=$(echo $updatesJson | jq '[.updates[]] | sort_by(.hash)')
updates=($(echo "$updatesJson" | jq -c -r '.[]'))

for update in "${!updates[@]}"; do
  updateObject=${updates[$update]}
  path="/tmp/updates/$(echo $updateObject | jq -r '.path')"
  id=$(echo $updateObject | jq -r '.hash')	

  echo "Processing $path"
  bash $path $USER_HOME $SSH_USER $VM_IP $HOST_IP
  exit_code=$?
  bool="true"
  if [ $exit_code -ne 0 ]; then
    bool="false"
  fi

  cat $USER_HOME/.installed | jq ". += {\"$id\": $bool}" > $USER_HOME/.installed.tmp
  mv $USER_HOME/.installed.tmp $USER_HOME/.installed
  chown $SSH_USER:$SSH_USER $USER_HOME/.installed

  if [ "$bool" = "false" ]; then
    echo "Error while processing $path"
    exit 1
  fi
done

rm -rf /tmp/updates

