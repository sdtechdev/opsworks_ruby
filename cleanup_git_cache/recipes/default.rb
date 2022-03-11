node[:deploy].each do |app_name, deploy|
  dir_name = File.join('/', 'srv', 'www', app_name, 'shared', 'cached-copy')
  directory dir_name do
    action :delete
    recursive true
  end
end
