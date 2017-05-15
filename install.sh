#! /usr/bin/env bash

DEF_IPABUDDY_ROOT="$( pwd )"

ipabuddy_root="${1:-$DEF_IPABUDDY_ROOT}"

(
[ ! -d /usr/local/bin ] && mkdir /usr/local/bin
cd /usr/local/bin
[ -L /usr/local/bin/ipabuddy ] && rm -rf /usr/local/bin/ipabuddy
ln -s ${ipabuddy_root}/ipabuddy.sh ipabuddy
)
