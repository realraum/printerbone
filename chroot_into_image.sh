#!/bin/zsh
# (c) Bernhard Tittelbach, 2018, GPLv3
local TARGETIMAGE=${1}
local MOUNTPTH=$(mktemp -d)

[[ -z $TARGETIMAGE ]] && {echo "Give .img filename"; exit 1}

local LOOPDEV=/dev/mapper/loop0


umountimage() {
  [ -e ${LOOPDEV}p2 ] && sudo umount ${LOOPDEV}p2
  sudo umount ${LOOPDEV}p1
  sleep 1
  sudo kpartx  -d -v $TARGETIMAGE
}

mountimage() {
    LOOPDEV=$(sudo kpartx  -l $TARGETIMAGE  | head -n1 | cut -d' ' -f 5 | sed 's:^/dev/:/dev/mapper/:')
    sudo kpartx  -a -v $TARGETIMAGE
    sleep 1.0
    sudo mount ${LOOPDEV}p1 $MOUNTPTH
    if [[ -e ${LOOPDEV}p2 ]] ; then
        sudo mount ${LOOPDEV}p2 ${MOUNTPTH}/var
    fi
}

runchroot() {
  sudo systemd-nspawn --bind /usr/bin/qemu-arm --bind /lib/x86_64-linux-gnu --bind /usr/lib/x86_64-linux-gnu/ --bind /lib64 -D "$MOUNTPTH" -- $*
}


mountimage
trap umountimage EXIT

runchroot /bin/bash


