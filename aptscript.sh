#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get purge --yes --allow-change-held-packages bonescript apache2-bin apache2-data apache2-utils apache2 c9-core-installer bb-node-red-installer nodejs bb-beaglebone-io-installer bb-johnny-five-installer
## do not upgrade, since it WILL upgrade the kernel which will not work inside qemu
#apt-get upgrade --yes
apt-get install --yes --no-install-recommends aptitude zsh git vim rsync python-cups cups-daemon cups cups-filters foomatic-db-compressed-ppds foomatic-db-engine python printer-driver-hpcups printer-driver-gutenprint htop tmux python3-cups
apt-get autoremove --yes
/bin/loginctl enable-linger debian
