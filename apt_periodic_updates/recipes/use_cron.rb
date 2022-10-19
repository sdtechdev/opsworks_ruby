# frozen_string_literal: true

default_path = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

node[:deploy].each do |app_name, deploy|
  systemd_unit 'apt-daily' do
    action :mask
  end

  systemd_unit 'apt-daily.timer' do
    action :mask
  end

  systemd_unit 'apt-daily-upgrade' do
    action :mask
  end

  systemd_unit 'apt-daily-upgrade.timer' do
    action :mask
  end

  cron 'apt-daily' do
    path default_path
    hour '*/2'
    user 'root'
    command '/usr/lib/apt/apt-helper wait-online; /usr/lib/apt/apt.systemd.daily update'
  end

  cron 'apt-daily-upgrade' do
    path default_path
    hour '*/2'
    minute '12'
    user 'root'
    command '/usr/lib/apt/apt.systemd.daily install'
  end
end
