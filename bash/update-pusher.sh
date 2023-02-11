#!/bin/bash

if ! apt list --installed 2> /dev/null | grep jq > /dev/null; then
  echo "jq is not installed"
  sudo -S apt install -y jq
fi

for f in /tmp/updates/*.sh; do
  echo "Processing $f"
  bash $f
  IN="$f"
  arrIN=(${IN//-/ })
  id=$(echo ${arrIN[0]} | sed 's/\/tmp\/updates\///g')

  bool="true"
  if [ $? -ne 0 ]; then
    bool="false"
  fi
  cat $HOME/.installed | jq ". += {\"$id\": $bool}" > $HOME/.installed.tmp
  mv $HOME/.installed.tmp $HOME/.installed

done

rm -rf /tmp/updates

