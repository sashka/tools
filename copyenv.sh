#!/bin/bash

# this script gonna copy my environment to remote server

if [ -z "$1" ];then
	echo "remote servername is not specified, use \"$0 <servername>\""
    exit 2
fi

akey=$(cat ~/.ssh/authorized_keys)
ssh "$1" "mkdir -p ~/.ssh;chmod 700 .ssh;echo "$akey" > .ssh/authorized_keys;chmod 600 .ssh/authorized_keys"
for i in bin .vimrc .screenrc .profile .bashrc;do
    scp -r "$i" "$1":
done

