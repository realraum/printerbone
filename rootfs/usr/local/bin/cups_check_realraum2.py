#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) Bernhard Tittelbach, 2018, GPLv3
#
import cups
import subprocess
import re
import os
import time
import sys              # System-specific parameters and functions.
import Adafruit_BBIO.GPIO as GPIO

relay_pin="P9_18"

time_needed_to_warm_up_print_pages_in_printer_mem_and_cool_down=5*60
time_between_checks=1*20
printers_name="HP_BUSINESS_INKJET_2250"
printer_usb_name="Magic Control Technology Corp. Parallel Port"

def isPrinterUsbConnected(printer_usb_name):
    try:
        lsusb = subprocess.check_output("lsusb")
        if printer_usb_name in lsusb:
            return True
    except:
        pass
    return False

def isPrinterKnownToCups(cc,printer_name_startswith):
    pl = filter(lambda x: x.startswith(printer_name_startswith), cc.getPrinters().keys())
    return (len(pl) > 0)

def getPrinterPowerStatus():
    return GPIO.input(relay_pin)

if __name__ == "__main__":
    GPIO.setup(relay_pin, GPIO.OUT)

    print "connecting to CUPS..."
    cc = cups.Connection()
    last_highest_completed_job_id = 1
    seconds_idle = 2*time_needed_to_warm_up_print_pages_in_printer_mem_and_cool_down
    print "isPrinterKnownToCups:", isPrinterKnownToCups(cc,printers_name)
    print "isPrinterUsbConnected:", isPrinterUsbConnected(printer_usb_name)
    while True:
        # jobs_pending = cc.getJobs(my_jobs=False)
        jobs_pending = filter(lambda jobid: cc.getJobAttributes(jobid,requested_attributes=["printer-uri"])["printer-uri"].endswith(printers_name),cc.getJobs(my_jobs=False).keys())
        printer_idle = len(jobs_pending) == 0
        job_ids_completed = filter(lambda jobid: cc.getJobAttributes(jobid,requested_attributes=["printer-uri"])["printer-uri"].endswith(printers_name),cc.getJobs(which_jobs="completed",first_job_id=last_highest_completed_job_id).keys())
        if job_ids_completed:
            last_highest_completed_job_id = max(job_ids_completed)
            seconds_idle = time.time() - cc.getJobAttributes(last_highest_completed_job_id,requested_attributes=["time-at-completed"])["time-at-completed"]

        #print "jobs_pending:", jobs_pending
        #print "printer_idle:", printer_idle, "last_highest_completed_job_id:", last_highest_completed_job_id,"seconds_idle:", seconds_idle

        printer_future_on = getPrinterPowerStatus()
        if printer_idle:
            if seconds_idle > time_needed_to_warm_up_print_pages_in_printer_mem_and_cool_down:
                printer_future_on = False
        else:
            printer_future_on = True

        printer_current_state_power = getPrinterPowerStatus()
        if printer_future_on != printer_current_state_power:
            if printer_future_on:
                GPIO.output(relay_pin,GPIO.HIGH)
            else:
                GPIO.output(relay_pin,GPIO.LOW)

        time.sleep(time_between_checks)
