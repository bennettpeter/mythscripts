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
grep "^$hwaddr " /etc/opt/mythtv/ipv6ulas.txt |
(
while true ; do
    read mac family ipadd comments
    if [[ "$mac" == "" ]] ; then break ; fi
    if [[ "$ipadd" != "" ]] ; then
        shortip=${ipadd%/*}
        if ! ip add|grep -w "$shortip" ; then
            echo "Adding IP Address $ipadd to $ifacename"
            ip $family address add $ipadd dev "$ifacename"
        fi
    fi
done
)
exit 0
