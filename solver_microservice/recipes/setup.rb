# frozen_string_literal: true

include_recipe 'poise-python'
include_recipe 'poise-application'

application node['assignment_solver']['working_dir'] do
  owner node['deployer']['user']
  group node['deployer']['group']

  pip_requirements

  git node['assignment_solver']['working_dir'] do
    repository node['assignment_solver']['repo_url']
    revision node['assignment_solver']['repo_branch']
  end

  gunicorn do
    port node['assignment_solver']['port']
    preload_app true
  end
end
