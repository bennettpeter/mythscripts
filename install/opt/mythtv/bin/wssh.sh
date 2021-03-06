#!/bin/bash

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
ssh_port=22
connect_ssh=Y

while (( "$#" >= 1 )) ; do
    case $1 in
        -p)
            ssh_port="$2"
            shift||rc=$?
            ;;
        -n)
            connect_ssh=N
            ;;
        -*)
            err=Y
            ;;
        *)
            if [[ "$machine" != "" ]] ; then err=Y ; fi
            machine="$1"
            ;;
    esac
    shift||rc=$?
done

if [[ "$err" == Y || "$machine" == "" ]] ; then 
    echo "Parameters"
    echo "-p port"
    echo "-n [do not connect ssh]"
    echo "machine"
    exit 2
fi

maxcount=50
for (( counter=0 ; counter<maxcount ; counter+=1 )) ; do
    $scriptpath/wakeup.sh "$machine"
    if [[ "$?" != 0 ]] ; then exit 2 ; fi
    nc -z -v $machine $ssh_port && break
    sleep 0.2
done

if [[ "$connect_ssh" == Y ]] ; then
    ssh -p $ssh_port $machine
fi

