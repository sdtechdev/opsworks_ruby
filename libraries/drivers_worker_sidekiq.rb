# frozen_string_literal: true

module Drivers
  module Worker
    class Sidekiq < Drivers::Worker::Base
      adapter :sidekiq
      allowed_engines :sidekiq
      output filter: %i[config process_count require syslog]
      packages debian: 'redis-server', rhel: 'redis'

      # keys to be stripped off from sidekiq.yml configuration
      EXTERNAL_CONFIGURATION_KEYS = %i[process_count maxmem_mb].freeze
      DEFAULT_MAXMEM_MB = 5000
      private_constant :EXTERNAL_CONFIGURATION_KEYS, :DEFAULT_MAXMEM_MB

      def configure
        add_sidekiq_config
        add_replica_config
      end

      def before_deploy
        quiet_sidekiq
      end

      def after_deploy
        add_replica_config
        disable_systemd
        restart_systemd
      end

      def shutdown
        quiet_sidekiq
        disable_systemd
        stop_sidekiq
      end

      alias after_undeploy after_deploy

      protected

      def restart_systemd
        (1..existing_configuration_size).each do |config_number|
          context.execute "systemctl stop sidekiq-#{config_number}"

          filename = "/etc/systemd/system/sidekiq-#{config_number}.service"
          context.file(filename) do
            action :delete
          end
        end

        deploy_to = deploy_dir(app)
        deploy = node['deploy'][app['shortname']]

        configuration.each.with_index(1) do |config, config_number|
          filename = "/etc/systemd/system/sidekiq-#{config_number}.service"
          max_memory = maxmem_mb(config, deploy)

          context.template filename do
            mode '0644'
            source "sidekiq.systemd.erb"
            variables(
              index: config_number,
              deploy_dir: deploy_to,
              user: node['deployer']['user'],
              group: node['deployer']['group'],
              process_count: config[:process_count],
              environment: deploy['global']['environment'],
              maxmem_mb: max_memory
            )
          end

          context.execute "systemctl enable sidekiq-#{config_number}"
          context.execute "systemctl start sidekiq-#{config_number}"
        end
      end

      def disable_systemd
        (1..existing_configuration_size).each do |config_number|
          context.execute "systemctl disable #{adapter}-#{config_number}" do
            retries 3
          end
        end
      end

      private

      def existing_configuration_size
        @_existing_configuration_size ||= `ls /etc/systemd/system/sidekiq* | wc -l`.chomp.to_i
      end

      def add_sidekiq_config
        deploy_to = deploy_dir(app)

        configuration.each.with_index(1) do |config, config_number|
          template_name = File.join(
            deploy_to, File.join('shared', 'config', "sidekiq_c#{config_number}.yml")
          )
          context.template template_name do
            owner node['deployer']['user']
            group www_group
            source 'sidekiq.conf.yml.erb'
            variables config: config.reject { |k, _| EXTERNAL_CONFIGURATION_KEYS.include?(k) }
          end
        end
      end

      def quiet_sidekiq
        (1..existing_configuration_size).each do |config_number|
          Chef::Log.info("Quiet Sidekiq process if exists: no. #{config_number}")

          context.execute("systemctl kill -s TSTP --kill-who=main sidekiq-#{config_number}") do
            ignore_failure true
          end
        end
      end

      def stop_sidekiq
        (1..existing_configuration_size).each do |config_number|
          Chef::Log.info("Stop Sidekiq process if exists: no. #{config_number}")

          command = "timeout 8 systemctl kill -s SIGTERM --kill-who=main sidekiq-#{config_number}"
          context.execute(command) do
            ignore_failure true
          end
        end
      end

      def configuration
        Array.wrap(JSON.parse(out[:config].to_json, symbolize_names: true))
      end

      def add_replica_config
        Chef::Log.info('Rewrite Sidekiq database.yml for read-replica')

        deploy = node['deploy'][app['shortname']]
        Chef::Log.info(deploy.inspect)
        context.template "#{deploy_dir(app)}/shared/config/database.yml" do
          source 'sidekiq_database.yml.erb'
          cookbook 'sidekiq_custom'
          mode '0660'
          group node['deployer']['group']
          owner node['deployer']['user']
          variables(
            database: deploy['database'],
            environment: deploy['global']['environment'],
            sidekiq_on_replica: deploy['sidekiq_on_replica']
          )
        end
      end

      # @param config [Hash]
      # @param deploy [Hash]
      # @return [Integer]
      def maxmem_mb(config, deploy)
        config[:maxmem_mb].to_i ||
          deploy['sidekiq_maxmem_mb'].to_i ||
          DEFAULT_MAXMEM_MB
      end
    end
  end
end
