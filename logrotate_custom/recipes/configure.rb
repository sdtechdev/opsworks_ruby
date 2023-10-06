# Write logrotate configuration

include_recipe 'logrotate'

template '/etc/logrotate.conf' do
  cookbook 'logrotate_custom'
  source 'logrotate-global.erb'
  owner 'root'
  group 'root'
  mode '0644'

  variables(
    options: %w[create weekly dateext],
    parameters: { 'rotate' => 4 },
    paths: {
      '/var/log/wtmp' => {
        'options' => %w[monthly],
        'parameters' => {
          'create' => '0664 root utmp',
          'minsize' => '1M',
          'rotate' => 1
        }
      },
      '/var/log/btmp' => {
        'options' => %w[missingok monthly],
        'parameters' => {
          'create' => '0600 root utmp',
          'rotate' => 1
        }
      }
    }
  )

  helpers do
    def nil_or_empty?(*values)
      values.any? { |v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    end
  end

  action :create
end

# template '/etc/crontab' do
#   cookbook 'logrotate_custom'
#   source 'crontab.erb'
#   owner 'root'
#   group 'root'
#   mode '0644'
#
#   variables(
#     cron_jobs: [
#       '@reboot /usr/sbin/logrotate -f /etc/logrotate.conf'
#     ]
#   )
#
#   action :create
# end


logrotate_app 'monit' do
  path       '/var/log/monit'
  options    ['missingok', 'notifempty']
  size       '100k'
  create     '0644 root root'
  postrotate ['/usr/bin/pkill -HUP -U root -x monit > /dev/null 2>&1 || :']
end

logrotate_app 'rsyslog' do
  path       '/var/log/syslog'
  options    ['missingok', 'notifempty', 'delaycompress', 'compress']
  size       '50M'
  create     '0644 root root'
  postrotate ['/usr/lib/rsyslog/rsyslog-rotate']
end

logrotate_app 'system' do
  path %w[/var/log/mail.info /var/log/mail.warn /var/log/mail.err /var/log/mail.log
          /var/log/daemon.log /var/log/kern.log /var/log/auth.log /var/log/user.log
          /var/log/lpr.log /var/log/cron.log /var/log/debug /var/log/messages]
  options    ['missingok', 'notifempty', 'delaycompress', 'compress', 'sharedscripts']
  frequency  'weekly'
  create     '0644 root root'
  rotate     4
  postrotate ['/usr/lib/rsyslog/rsyslog-rotate']
end
