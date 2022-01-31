name "logrotate_custom"
maintainer "sdtechdev"
description "Configures logrotate"
version "0.1"

recipe "logrotate_custom::configure", "Write custom Logrotate configuration."

depends 'logrotate', '2.2.1'
