#!/bin/bash

# To be linked to /etc/network/if-up.d/
# or /etc/NetworkManager/dispatcher.d/
# See man interfaces and man networkmanager

ifacename="$1"
action="$2"

if [[ "$ifacename" == "" && "$action" == "" ]] ; then
    # In this case assume it is called from if-up.d
    ifacename="$IFACE"
    action=up
fi

if [[ "$ifacename" == "" || "$action" != up ]] ; then exit ; fi

set -- `ifconfig|grep "^$ifacename "`
hwaddr="$5"
set -- `grep "^$hwaddr " /etc/opt/mythtv/ipv6ulas.txt`
ipadd="$2"

if [[ "$ipadd" != "" ]] ; then
    if ifconfig|grep -w "$ipadd" ; then exit ; fi
    echo "Adding IP Address $ipadd to $ifacename"
   ip -6 address add $ipadd dev "$ifacename"
fi
