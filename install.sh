#! /usr/bin/env bash

(
install_dir=$(pwd)
[ ! -d /usr/local/bin ] && mkdir /usr/local/bin
cd /usr/local/bin
ln -s ${install_dir}/ipabuddy.sh ipabuddy
)

