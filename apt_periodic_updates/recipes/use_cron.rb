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
end
