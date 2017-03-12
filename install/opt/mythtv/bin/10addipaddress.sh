#!/bin/bash

ifacename="$1"
action="$2"

if [[ "$CONNECTION_UUID" == "" ]] ; then exit ; fi

set -- `grep "$CONNECTION_UUID" /etc/opt/mythtv/ipv6ulas.txt`
ipadd="$2"

if [[ "$ipadd" != "" ]] ; then
    echo "Adding IP Address $ipadd"
   ip -6 address add $ipadd dev "$ifacename"
fi
