# frozen_string_literal: true

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
    hour '6'
    user 'root'
    command '/usr/lib/apt/apt-helper wait-online; /usr/lib/apt/apt.systemd.daily update'
  end

  cron 'apt-daily-upgrade' do
    hour '6,18'
    minute '10'
    user 'root'
    command '/usr/lib/apt/apt.systemd.daily install'
  end
end
