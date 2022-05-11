# frozen_string_literal: true

pip 'pipenv'

git node['assignment_solver']['working_dir'] do
  user node['deployer']['user']
  group node['deployer']['group']

  repository node['assignment_solver']['repo_url']
  revision node['assignment_solver']['repo_branch']

  action :sync
end

execute 'install dependencies' do
  cwd node['assignment_solver']['working_dir']
  user node['deployer']['user']

  command 'pipenv install'

  action :run
end

execute 'run solver' do
  cwd node['assignment_solver']['working_dir']
  user node['deployer']['user']

  address = node['assignment_solver']['address']
  port = node['assignment_solver']['port']
  command "pipenv run gunicorn -b #{address}:#{port} -D application:application"

  action :run
end
