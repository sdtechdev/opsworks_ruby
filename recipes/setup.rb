# frozen_string_literal: true

#
# Cookbook Name:: opsworks_ruby
# Recipe:: setup
#

if node['ruby-provider'] != 'fullstaq'
  apt_repository 'fullstaq-ruby' do
    action :remove
  end
end

include_recipe 'apt'
include_recipe 'nodejs'

prepare_recipe

if node['patches']['chef12_ssl_fix']
  remote_file 'Copy more recent root certificate into Chef' do
    path '/opt/chef/embedded/ssl/certs/cacert.pem'
    source 'file:///etc/ssl/certs/ca-certificates.crt'
    owner 'root'
    group 'root'
    mode '0644'
  end
end

# Upgrade chef
# Taken from `chef-upgrade` cookbook <https://github.com/inopinatus/chef-upgrade> by Josh Goodall
# The Chef updater will try to kill its own process. This causes setup failure.
# We force it to accept our "exec" configuration by monkey-patching the LWRP.
if node['chef-version']
  update_provider = Chef.provider_handler_map.get(node, :chef_client_updater)
  update_provider.prepend(CannotSelfTerminate)
  include_recipe 'chef_client_updater::default'

  directory '/opt/aws/opsworks/current/plugins' do
    owner 'root'
    group 'aws'
    mode '0755'
    recursive true
  end

  cookbook_file '/opt/aws/opsworks/current/plugins/debian_downgrade_protection.rb' do
    source 'debian_downgrade_protection.rb'
    owner 'root'
    group 'aws'
    mode '0644'
  end
end

# Create deployer user
group node['deployer']['group'] do
  gid 5000
end

user node['deployer']['user'] do
  comment 'The deployment user'
  uid 5000
  gid 5000
  shell '/bin/bash'
  home node['deployer']['home']
  manage_home true
end

sudo node['deployer']['user'] do
  user      node['deployer']['user']
  group     node['deployer']['group']
  commands  %w[ALL]
  host      'ALL'
  nopasswd  true
end

# Monit and cleanup
if node['platform_family'] == 'debian'
  execute 'mkdir -p /etc/monit/conf.d'

  file '/etc/monit/conf.d/00_httpd.monitrc' do
    content "set httpd port 2812 and\n    use address localhost\n    allow localhost"
  end

  apt_package 'javascript-common' do
    action :purge
  end
end

if node['platform_family'] == 'debian'
  execute 'add yarn repository key' do
    command 'curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -'
    command 'apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8'
    user 'root'
  end
end

if node['use-nodejs']
  # NodeJS and Yarn
  include_recipe 'nodejs'
  include_recipe 'yarn'
end

# Ruby and bundler
if node['ruby-provider'] == 'fullstaq'
  # fullstaq-ruby provider
  if node['platform_family'] == 'debian'
    package 'gnupg2'

    # For whatever reason `apt_repository.key` doesn't work here.
    remote_file "#{Chef::Config[:file_cache_path]}/fullstaq-ruby.asc" do
      source 'https://raw.githubusercontent.com/fullstaq-labs/fullstaq-ruby-server-edition/main/fullstaq-ruby.asc'
    end

    execute 'add fullstaq repository key' do
      command "apt-key add #{Chef::Config[:file_cache_path]}/fullstaq-ruby.asc"
      user 'root'
    end

    apt_repository 'fullstaq-ruby' do
      uri 'https://apt.fullstaqruby.org'
      distribution "#{node['lsb']['id'].downcase}-#{node['lsb']['release']}"
      components %w[main]
      only_if { node['ruby-provider'] == 'fullstaq' }
    end
  else
    yum_repository 'fullstaq-ruby' do
      baseurl 'https://yum.fullstaqruby.org/centos-7/$basearch'
      enabled true
      gpgcheck false
      gpgkey 'https://raw.githubusercontent.com/fullstaq-labs/fullstaq-ruby-server-edition/main/fullstaq-ruby.asc'
      repo_gpgcheck true
      sslverify true
      only_if { node['ruby-provider'] == 'fullstaq' }
    end
  end

  ruby_package_ver = [node['ruby-version'], node['ruby-variant']].select(&:present?).join('-')
  path = "/usr/lib/fullstaq-ruby/versions/#{ruby_package_ver}/bin:" \
         '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games'

  package "fullstaq-ruby-#{ruby_package_ver}"

  template '/etc/environment' do
    source 'environment.erb'
    mode 0o664
    owner 'root'
    group 'root'
    variables(environment: { 'PATH' => path })
  end

  execute 'update bundler' do
    command "/usr/lib/fullstaq-ruby/versions/#{ruby_package_ver}/bin/gem update bundler"
    user 'root'
    environment('PATH' => path)
  end

  link '/usr/local/bin/bundle' do
    to "/usr/lib/fullstaq-ruby/versions/#{ruby_package_ver}/bin/bundle"
  end

  link '/usr/local/bin/ruby' do
    to "/usr/lib/fullstaq-ruby/versions/#{ruby_package_ver}/bin/ruby"
  end
elsif node['ruby-provider'] == 'ruby-ng'
  # ruby-ng provider
  if node['platform_family'] == 'debian'
    node.default['ruby-ng']['ruby_version'] = node['ruby-version']
    include_recipe 'ruby-ng::dev'

    link '/usr/local/bin/bundle' do
      to '/usr/bin/bundle'
    end
  else
    ruby_pkg_version = node['ruby-version'].split('.')[0..1]
    package "ruby#{ruby_pkg_version.join}"
    package "ruby#{ruby_pkg_version.join}-devel"
    execute "/usr/sbin/alternatives --set ruby /usr/bin/ruby#{ruby_pkg_version.join('.')}"

    link '/usr/local/bin/bundle' do
      to '/usr/local/bin/bundler'
    end
  end

  bundler2_applicable = Gem::Requirement.new('>= 3.0.0.beta1').satisfied_by?(
    Gem::Version.new(Gem::VERSION)
  )
  gem_package 'bundler' do
    action :install
    version '~> 1' unless bundler2_applicable
  end
else
  chruby_pgp_key_path = ::File.join(Chef::Config[:file_cache_path], 'chruby.tar.gz.asc')
  tar_path = ::File.join(Chef::Config[:file_cache_path], 'chruby.tar.gz')
  postmodern_pgp_key_path = ::File.join(Chef::Config[:file_cache_path], 'postmodern.asc')

  package 'gnupg'
  package 'make'

  remote_file tar_path do
    source 'https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz'
    owner 'root'
    group 'root'
    mode '0755'
  end

  remote_file chruby_pgp_key_path do
    source 'https://raw.github.com/postmodern/chruby/master/pkg/chruby-0.3.9.tar.gz.asc'
    owner 'root'
    group 'root'
    mode '0755'
  end

  remote_file postmodern_pgp_key_path do
    source 'https://raw.github.com/postmodern/postmodern.github.io/master/postmodern.asc'
    owner 'root'
    group 'root'
    mode '0755'
    notifies :run, 'execute[Import GPG Key]', :immediately
  end

  execute 'Import GPG Key' do
    command "gpg --import #{postmodern_pgp_key_path}"
    notifies :run, 'execute[verify tar]', :immediately
    action :nothing
  end

  execute 'verify tar' do
    command "gpg --verify #{chruby_pgp_key_path} #{tar_path}"
    notifies :run, 'execute[install chruby]', :immediately
    action :nothing
  end

  execute 'install chruby' do
    cwd Chef::Config[:file_cache_path]
    command <<-EOH
      tar -xzvf chruby.tar.gz
      cd chruby-0.3.9
      sudo make install
    EOH
    action :nothing
  end

  file '/etc/profile.d/chruby.sh' do
    content(
      <<~STR
        if [ -n \"\$BASH_VERSION\" ] || [ -n \"\$ZSH_VERSION\" ]; then
        	source /usr/local/share/chruby/chruby.sh
        	source /usr/local/share/chruby/auto.sh
          chruby ruby-#{node['ruby-version']}
        fi
      STR
    )
    mode '0644'
    owner 'root'
    group 'root'
    action :create_if_missing
  end

  [
    'source /usr/local/share/chruby/chruby.sh',
    'source /usr/local/share/chruby/auto.sh',
    'chruby ruby-2.7.6'
  ].each do |line|
    bash 'append to /etc/bash.bashrc' do
      code <<~EOH
        if ! grep -F "#{line}" "/etc/bash.bashrc"; then
          echo #{line} >> "/etc/bash.bashrc"
        fi
      EOH
      user 'root'
    end
  end

  remote_file 'ruby-install-0.9.1.tar.gz.asc' do
    source 'https://github.com/postmodern/ruby-install/releases/download/v0.9.1/ruby-install-0.9.1.tar.gz.asc'
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  remote_file 'ruby-install-0.9.1.tar.gz' do
    source 'https://github.com/postmodern/ruby-install/releases/download/v0.9.1/ruby-install-0.9.1.tar.gz'
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  execute 'verify ruby-install signature' do
    command 'gpg --verify ruby-install-0.9.1.tar.gz.asc ruby-install-0.9.1.tar.gz'
  end

  execute 'extract ruby-install source' do
    command 'tar -xzvf ruby-install-0.9.1.tar.gz'
  end

  execute 'make install' do
    command 'make install'
    cwd 'ruby-install-0.9.1'
    user 'root'
  end

  execute 'install ruby version' do
    command "ruby-install ruby #{node['ruby-version']}"
  end

  path = "/opt/rubies/ruby-#{node['ruby-version']}/bin:" \
         '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
  execute 'update bundler' do
    command "/opt/rubies/ruby-#{node['ruby-version']}/bin/gem update bundler"
    user 'root'
    environment('PATH' => path)
  end

  link '/usr/local/bin/bundle' do
    to "/opt/rubies/ruby-#{node['ruby-version']}/bin/bundle"
  end

  link '/usr/local/bin/ruby' do
    to "/opt/rubies/ruby-#{node['ruby-version']}/bin/ruby"
  end
end

apt_repository 'apache2' do
  uri 'http://ppa.launchpad.net/ondrej/apache2/ubuntu'
  distribution node['lsb']['codename']
  components %w[main]
  keyserver 'keyserver.ubuntu.com'
  key 'E5267A6C'
  only_if { node['defaults']['webserver']['use_apache2_ppa'] }
end

apt_repository 'nginx' do
  uri        'http://nginx.org/packages/ubuntu/'
  components ['nginx']
  keyserver 'keyserver.ubuntu.com'
  key 'ABF5BD827BD9BF62'
  only_if { node['defaults']['webserver']['adapter'] == 'nginx' }
end

execute 'yum-config-manager --enable epel' if node['platform_family'] == 'rhel'

every_enabled_application do |application|
  databases = []
  every_enabled_rds(self, application) do |rds|
    databases.push(Drivers::Db::Factory.build(self, application, rds: rds))
  end

  source = Drivers::Source::Factory.build(self, application)
  framework = Drivers::Framework::Factory.build(self, application, databases: databases)
  appserver = Drivers::Appserver::Factory.build(self, application)
  worker = Drivers::Worker::Factory.build(self, application, databases: databases)
  webserver = Drivers::Webserver::Factory.build(self, application)

  fire_hook(:setup, items: databases + [source, framework, appserver, worker, webserver])
end

# setup hooks for appservers and workers may need to reload monit configs
execute 'monit reload' do
  action :nothing
  only_if 'which monit'
end

aws_cloudwatch_agent 'default' do
  action      [:install, :configure, :restart]
  json_config 'amazon-cloudwatch-agent.json.erb'
end

if node['platform_family'] == 'debian'
  apt_package %w[awscli wget ca-certificates]

  execute 'download key' do
    command 'wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -'
  end

  apt_repository 'pgdg' do
    uri 'https://apt-archive.postgresql.org/pub/repos/apt'
    distribution 'bionic-pgdg'
    components %w[main]
  end

  execute 'apt update' do
    command 'apt-get update'
    user 'root'
  end

  apt_package 'postgresql-client-12'
end

# Imagemagick Installation
apt_package 'libpng-dev'
apt_package 'libwebp-dev'
apt_package 'libjpeg-dev'
imagemagick_archive_path = ::File.join(Chef::Config[:file_cache_path], 'imagemagick-6.9.10-97.tar.xz')

remote_file imagemagick_archive_path do
  source 'https://imagemagick.org/archive/releases/ImageMagick-6.9.10-97.tar.xz'
  owner 'root'
  group 'root'
  mode '0755'
end

execute 'install imagemagick' do
  cwd Chef::Config[:file_cache_path]
  command <<-EOH
    tar -xf imagemagick-6.9.10-97.tar.xz
    cd ImageMagick-6.9.10-97
    ./configure
    sudo make install
    ldconfig /usr/local/lib
  EOH
  action :run
end

template '/usr/local/etc/ImageMagick-6/policy.xml' do
  source 'imagemagick-policy.xml'
  mode 0644
  owner 'root'
  group 'root'
end

# install rsvg-convert tool, for converting and resizing SVG image to PNG
apt_package 'librsvg2-bin'
