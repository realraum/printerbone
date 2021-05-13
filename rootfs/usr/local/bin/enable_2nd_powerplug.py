#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) Bernhard Tittelbach, 2018, GPLv3
#
import re
import os
import time
import sys              # System-specific parameters and functions.
import Adafruit_BBIO.GPIO as GPIO

relay_pin="P9_18"

## this is where currently, USB-Hub is powered


if __name__ == "__main__":
    GPIO.setup(relay_pin, GPIO.OUT)

    GPIO.output(relay_pin,GPIO.HIGH)
    
    while True:
        time.sleep(10)
