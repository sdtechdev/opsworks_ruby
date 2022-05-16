# frozen_string_literal: true

version = '3.8.13'
user    = node['deployer']['user']

pyenv_user_install user

pyenv_python version do
  user user
end

pyenv_global version do
  user user
end

pyenv_pip 'pipenv' do
  user    user
end


git node['assignment_solver']['working_dir'] do
  user user
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
