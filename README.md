r3 Pinterserver Beaglebone
==========================

Purpose
-------

Have an Beaglebone sit as printer-server between our power-hungry and insecure HP-Laserjet 8000 and our network. The Beaglebone is connected to an relay and power-switches the printer off if not in use.

### Advantages

- trade insecurity of HP printer IP stack with somewhat secure and updateable debian system
- faster printing
- power saving

Usage
-----

The script <tt>modify_image.sh</tt> takes as argument a standard debian-based beaglebone IOT image and modifies ist.

Modifiactions include:

- repartitioning so / can be ro, while /var is rw and everything still fits on the internal eMMC if desired
- removing nodejs shit
- adding cups and needed packages
- configure ssh and passwords


License
-------

GPLv3 or if that's too cumbersome "use as you see fit but drop be a msg that you do".

Todo
----

- improve configuration (what are shell variable at the top right now)
- write python framework to work with existing images and then publish that code instead of depending on currently not included python-scripts
- use Ansible instead of shell script
