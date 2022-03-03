# frozen_string_literal: true

module Drivers
  module Worker
    class Sidekiq < Drivers::Worker::Base
      adapter :sidekiq
      allowed_engines :sidekiq
      output filter: %i[config process_count require syslog]
      packages 'monit', debian: 'redis-server', rhel: 'redis'

      def configure
        add_sidekiq_config
        add_replica_config
        add_worker_monit
      end

      def before_deploy
        quiet_sidekiq
      end

      def after_deploy
        add_replica_config
        restart_monit
      end

      def shutdown
        quiet_sidekiq
        unmonitor_monit
        stop_sidekiq
      end

      alias after_undeploy after_deploy

      protected

      def restart_monit
        return if ENV['TEST_KITCHEN']

        context.execute "monit restart -g sidekiq_#{app['shortname']}_group" do
          retries 3
        end
      end

      def unmonitor_monit
        (1..configuration.size).each do |config_number|
          context.execute "monit unmonitor #{adapter}_#{app['shortname']}-c#{config_number}" do
            retries 3
          end
        end
      end

      private

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
            variables config: config.reject { |k, _| k == :process_count }
          end
        end
      end

      def quiet_sidekiq
        (1..configuration.size).each do |config_number|
          Chef::Log.info("Quiet Sidekiq process if exists: no. #{config_number}")

          context.execute(send_signal_to_sidekiq(config_number, :TSTP))
        end
      end

      def stop_sidekiq
        (1..configuration.size).each do |config_number|
          timeout = (out[:config]['timeout'] || 8).to_i
          Chef::Log.info("Stop Sidekiq process if exists: no. #{config_number}")

          context.execute("timeout #{timeout} #{send_signal_to_sidekiq(config_number)}")
        end
      end

      def send_signal_to_sidekiq(config_number, signal = nil)
        "/bin/su - #{node['deployer']['user']} -c \"ps -ax | grep 'bundle exec sidekiq' | " \
          "grep sidekiq_c#{config_number}.yml | grep -v grep | awk '{print \\$1}' | " \
          "xargs --no-run-if-empty pgrep -P | xargs --no-run-if-empty kill#{" -#{signal}" if signal}\""
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
    end
  end
end
