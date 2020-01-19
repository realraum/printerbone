#!/bin/zsh
# (c) Bernhard Tittelbach, 2018, GPLv3
local TARGETIMAGE=${1}
local BBHOSTNAME=${2:-drucker.realraum.at}
local BBSHORTHOST=${${(s:.:)BBHOSTNAME}[1]}
local MOUNTPTH=$(mktemp -d)
local APTSCRIPT=./aptscript.sh
local LOCALROOT=./rootfs
local MYSSHPUBKEY=~/.ssh/id_rsa_realraum.pub
local MAINUSER=debian
local R3PASS_STORELOC=devices/drucker/debian
R3NOCPASSDIR=${R3NOCPASSDIR:-~/realraum/noc-pass}

[[ -z $TARGETIMAGE ]] && {echo "Give .img filename"; exit 1}
[[ -z $APTSCRIPT ]] && exit 2
[[ -z $LOCALROOT ]] && exit 3

echo "Modify and and configure $TARGETIMAGE ?"
read -q || exit 1

local LOOPDEV=/dev/mapper/loop0

extendimage() {
  local imgtargetsize=$((1024*1024*3400))
  local shrinkrootsize=$((1024*1024*2300))
  local num_expected_partitions=1
  local num_partitions_in_image=$(sfdisk -d -q "$TARGETIMAGE" | tail "+6" | wc -l)
  [[ $num_partitions_in_image -eq $num_expected_partitions ]] || return 1
  sudo ~/work/briefcasebiotec/kilobaser/raspi/shrink_partition_inside_image.py "$TARGETIMAGE" "$shrinkrootsize" || return 2
  ~/work/briefcasebiotec/kilobaser/raspi/extend_image_and_append_partition.py "$TARGETIMAGE" "$imgtargetsize" || return 3
}

umountimage() {
  [ -e ${LOOPDEV}p2 ] && sudo umount ${LOOPDEV}p2
  sudo umount ${LOOPDEV}p1
  sleep 1
  sudo kpartx  -d -v $TARGETIMAGE
}

setpassword() {
  local user=$1
  local passloc=$2
  local pass=$(PASSWORD_STORE_DIR=${R3NOCPASSDIR} pass "$passloc" | head -n1)
  echo -e "root:${pass}\n${user}:${pass}" | runchroot chpasswd
}

mountimagemvvar() {
    LOOPDEV=$(sudo kpartx  -l $TARGETIMAGE  | head -n1 | cut -d' ' -f 5 | sed 's:^/dev/:/dev/mapper/:')
    sudo kpartx  -a -v $TARGETIMAGE
    sleep 1.0
    sudo mount ${LOOPDEV}p1 $MOUNTPTH
    if [[ -e ${LOOPDEV}p2 ]] ; then
        if ! sudo mount ${LOOPDEV}p2 ${MOUNTPTH}/var; then
            sudo mkfs -L var -t ext4 ${LOOPDEV}p2 || exit 2
            mvvar
            sudo mount ${LOOPDEV}p2 ${MOUNTPTH}/var
        fi
    fi
}

mvvar() {
  local TDIR=$(mktemp -d)
  sudo mount ${LOOPDEV}p2 $TDIR
  sudo mv ${MOUNTPTH}/var/*(D) ${TDIR}/
  echo '/dev/mmcblk0p2  /var  ext4  noatime,errors=remount-ro  0  1' | sudo tee -a ${MOUNTPTH}/etc/fstab
  sync
  sudo umount ${LOOPDEV}p2
}

runchroot() {
  sudo systemd-nspawn --bind /usr/bin/qemu-arm --bind /lib/x86_64-linux-gnu --bind /usr/lib/x86_64-linux-gnu/ --bind /lib64 -D "$MOUNTPTH" -- $*
}

fixuEnv() {
  local uenv="${1:-$MOUNTPTH/boot/uEnv.txt}"
  sudo sed 's/^dtb=/#dtb=/;s/^\(cmdline=.*\) \w\+=enable$/\1/' -i "$uenv"

  ## disable eMMC/HDMI cape for green/black
  #echo "dtb=am335x-bonegreen-overlay.dtb" | sudo tee -a "$uenv"
  ## oder
  ## echo "dtb=am335x-boneblack-overlay.dtb" >> "$uenv"

  ## disable HDMI & Audio but NOT eMMC
  echo "disable_uboot_overlay_video=1" | sudo tee -a "$uenv"
  echo "disable_uboot_overlay_audio=1" | sudo tee -a "$uenv"

  ## set pin P9_12 / GPIO60 to OUT and LOW
  echo "dtb_overlay=/lib/firmware/XRO_P9_12_7-00A0.dtbo" | sudo tee -a "$uenv"
 
  ## diff  am335x-boneblack-overlay.dts  am335x-bonegreen-overlay.dts
  ## 6c6
  ## <       compatible = "ti,am335x-bone-black", "ti,am335x-bone", "ti,am33xx";
  ## ---
  ## >       compatible = "ti,am335x-bone-green", "ti,am335x-bone-black", "ti,am335x-bone", "ti,am33xx";
  ## 8c8
  ## <       model = "TI AM335x BeagleBone Black";
  ## ---
  ## >       model = "TI AM335x BeagleBone Green";
}

disabledhcpfor() {
  local interfaces="${1:-usb0}"
  local dhcpcdconf="$MOUNTPTH/etc/dhcpcd.conf"
  echo -e "\ndenyinterfaces $interfaces" | sudo tee -a "$dhcpcdconf"
}

gobuildandcp() {
( cd "$1"
  export GOARCH=arm
  export GOOS=linux
  export CGO_ENABLED=0
  go build
)
  sudo mkdir -p "${2}"
  sudo cp -v "${1}/${1:t}" "${2}"
}


TRAPEXIT() {umountimage}
extendimage || exit 1
mountimagemvvar || exit 2
TRAPINT() {
  print "Caught SIGINT, aborting."
  umountimage
  return $(( 128 + $1 ))
}

## install/remove packages
runchroot /bin/bash < $APTSCRIPT

## fix uEnv.txt
fixuEnv

## settings and stuff
sudo rsync --chown=root:root -va ${LOCALROOT}/  ${MOUNTPTH}/

## remake initramfs for /lib/firmware files added to uEnv
#runchroot /usr/sbin/update-initramfs -u

## set permissions for cups files
sudo chown root:lp  -R ${MOUNTPTH}/etc/cups/ppd
sudo chmod a=,u=rwX,g=rX -R ${MOUNTPTH}/etc/cups/ppd

## tmpfs and other stuff for ro-root
echo 'none    /tmp    tmpfs   rw,nosuid,nodev,mode=755        0 0' | sudo tee -a ${MOUNTPTH}/etc/fstab
ln -sf /proc/self/mounts  /etc/mtabs

## Hostname
echo "$BBHOSTNAME" | sudo tee ${MOUNTPTH}/etc/hostname
sudo sed -i "s/beaglebone.localdomain\\s\\+beaglebone/$BBHOSTNAME  $BBSHORTHOST/" ${MOUNTPTH}/etc/hosts 

## ssh keys
sudo mkdir -p ${MOUNTPTH}/root/.ssh ${MOUNTPTH}/home/$MAINUSER/.ssh
cat $MYSSHPUBKEY | sudo tee -a ${MOUNTPTH}/root/.ssh/authorized_keys
cat $MYSSHPUBKEY | sudo tee -a ${MOUNTPTH}/home/$MAINUSER/.ssh/authorized_keys

## newest zsh config
[[ -e ~/.zshrc ]] && sudo cp ~/.zshrc(N) ~/.zshrc.local(N) ${MOUNTPTH}/home/$MAINUSER/
sudo chown 1000:1000 -R ${MOUNTPTH}/home/$MAINUSER/
sudo chmod a=,g=rX,u=rwX ${MOUNTPTH}/home/$MAINUSER/
sudo chmod a=,u=rwX -R ${MOUNTPTH}/home/$MAINUSER/.ssh/
[[ -e ~/.zshrc ]] && sudo cp ~/.zshrc(N) ~/.zshrc.local(N) ${MOUNTPTH}/root/

## set root read-only
sudo sed -i '/mmcblk0p1/s/noatime,/noatime,ro,/' ${MOUNTPTH}/etc/fstab

setpassword $MAINUSER $R3PASS_STORELOC

## compile and install webserver for uploads
git submodule update ./golang-http-file-upload 
gobuildandcp ./golang-http-file-upload ${MOUNTPTH}/usr/local/bin/

### ssh-keygen for hostkeys...
runchroot /usr/sbin/dpkg-reconfigure openssh-server
runchroot /usr/bin/chsh -s /bin/zsh root
runchroot /usr/bin/chsh -s /bin/zsh $MAINUSER
runchroot /usr/bin/zsh


