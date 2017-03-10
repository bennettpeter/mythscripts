#!/bin/bash

ifacename="$1"
action="$2"

if [[ "$CONNECTION_UUID" == 8d8d0532-0b4c-3566-845b-fe9fb4a80d42 \
   && "$action" == up ]] ; then
   ip -6 address add fd3d:63f5:6a89::1/64 dev "$ifacename"
fi
if [[ "$CONNECTION_UUID" == e45aa478-9957-3537-a87e-7396ce3bf6dc \
   && "$action" == up ]] ; then
   ip -6 address add fd3d:63f5:6a89::2/64 dev "$ifacename"
fi
