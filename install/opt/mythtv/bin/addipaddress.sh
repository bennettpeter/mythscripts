#!/bin/bash

# To be linked to /etc/network/if-up.d/
# or /etc/NetworkManager/dispatcher.d/
# See man interfaces and man networkmanager
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

ifacename="$1"
action="$2"

if [[ "$ifacename" == "" && "$action" == "" && "$IFACE" != "" ]] ; then
    # In this case assume it is called from if-up.d
    ifacename="$IFACE"
    action=up
fi

if [[ "$ifacename" == "all" ]] ; then
    for ifname in `ifconfig | grep '^[^ ]' | sed 's/[: ].*$//'` ; do
        $scriptpath/addipaddress.sh $ifname up
    done
    exit 0
fi

if [[ "$ifacename" == "" || "$action" != up ]] ; then exit 0; fi

hwaddr=`ifconfig $ifacename | grep Ethernet | sed 's/.*\(..:..:..:..:..:..\).*/\1/'`
set -- `grep "^$hwaddr " /etc/opt/mythtv/ipv6ulas.txt`
ipadd="$2"

if [[ "$ipadd" != "" ]] ; then
    shortip=${ipadd%/*}
    if ifconfig|grep -w "$shortip" ; then exit 0; fi
    echo "Adding IP Address $ipadd to $ifacename"
    ip -6 address add $ipadd dev "$ifacename"
fi
exit 0
