#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get purge --yes --allow-change-held-packages bonescript apache2-bin apache2-data apache2-utils apache2 c9-core-installer bb-node-red-installer nodejs bb-beaglebone-io-installer bb-johnny-five-installer bone101
## do not upgrade, since it WILL upgrade the kernel which will not work inside qemu
#apt-get upgrade --yes
apt-get install --yes --no-install-recommends aptitude zsh git vim rsync python-cups python-pip cups-daemon cups cups-filters foomatic-db-compressed-ppds foomatic-db-engine python printer-driver-hpcups printer-driver-gutenprint htop tmux python3-cups python3-pip samba printer-driver-cups-pdf lpr
apt-get autoremove --yes
pip install Adafruit_BBIO
pip3 install Adafruit_BBIO
pip install paho-mqtt
pip3 install paho-mqtt
/bin/loginctl enable-linger debian
