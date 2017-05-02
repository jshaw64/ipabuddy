#! /usr/bin/env bash

(
install_dir="$(dirname "${BASH_SOURCE[0]}")"
[ ! -d /usr/local/bin ] && mkdir /usr/local/bin
cd /usr/local/bin
ln -s ${install_dir}/ipabuddy.sh ipabuddy
)

