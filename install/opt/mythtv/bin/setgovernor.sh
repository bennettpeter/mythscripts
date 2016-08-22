#!/bin/bash
# Input parameter high or normal
# Must run under root

option=$1
case $option in 
  high)
    setting=performance
    ;;
  normal)
    arch=`arch`
    case $arch in 
      armv*)
        setting=ondemand
        ;;
      *)
        setting=powersave
        ;;
    esac
    ;;
  *)
    echo valid options high or normal
    echo "ERROR invalid option $option" >&2
    exit 2
    ;;
esac
echo "setting governor to $setting"
echo "$setting" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor


        


