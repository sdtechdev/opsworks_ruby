# frozen_string_literal: true

node[:deploy].each do |app_name, deploy|
  cron 'apt-daily' do
    action :delete
  end

  cron 'apt-daily-upgrade' do
    action :delete
  end

  systemd_unit 'apt-daily' do
    action :unmask
  end

  systemd_unit 'apt-daily.timer' do
    action [:unmask, :restart]
  end

  systemd_unit 'apt-daily-upgrade' do
    action :unmask
  end

  systemd_unit 'apt-daily-upgrade.timer' do
    action [:unmask, :restart]
  end
end
