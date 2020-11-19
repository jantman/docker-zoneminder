#!/bin/sh

exec chpst -u www-data /usr/bin/zmeventnotification.pl 2>&1
