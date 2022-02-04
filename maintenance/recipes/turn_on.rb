# frozen_string_literal: true

node[:deploy].each do |app_name, deploy|
  template "#{::File.join('/', 'srv', 'www', app_name)}/current/public/maintenance.html" do
    source 'maintenance.html.erb'
    owner deploy['user']
    variables(estimated_end_time: node[:maintenance][:estimated_end_time])
  end

  file "#{::File.join('/', 'srv', 'www', app_name)}/current/public/offline" do
    user deploy['user']
    action :touch
  end
end
