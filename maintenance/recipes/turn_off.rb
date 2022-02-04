# frozen_string_literal: true

node[:deploy].each do |app_name, deploy|
  file "#{::File.join('/', 'srv', 'www', app_name)}/current/public/offline" do
    user deploy['user']
    action :delete
  end
end
