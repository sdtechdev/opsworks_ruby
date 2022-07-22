name "apt_periodic_updates"
maintainer "sdtechdev"
description "Replaces systemd-based apt updates by cron-based ones"
version "0.1"

recipe "apt_periodic_updates::use_cron", "Replace systemd-based apt updates by cron-based ones"
recipe "apt_periodic_updates::use_systemd", "Replace cron-based apt updates by systemd-based ones"
