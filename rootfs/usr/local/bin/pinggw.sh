#!/bin/sh
GW=$(ip route get 127.0.0.1 8.8.8.8 | head -n1 | cut -d" " -f 3)
[ -n "$GW" ] && ping -qc20 $GW 2>&1 >/dev/null &
exit 0
