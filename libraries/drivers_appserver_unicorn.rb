# frozen_string_literal: true

module Drivers
  module Appserver
    class Unicorn < Drivers::Appserver::Base
      adapter :unicorn
      allowed_engines :unicorn
      output filter: %i[
        backlog delay preload_app tcp_nodelay tcp_nopush tries timeout worker_processes
        port
      ]

      def configure
        add_appserver_service_script
        super
      end

      def after_deploy
        deploy_to = deploy_dir(app)

        context.execute "restart unicorn using restart" do
          script_path = File.join(deploy_to, File.join('shared', 'scripts', 'unicorn'))
          command "#{script_path} restart"
          live_stream true
        end

        super
      end

      def after_undeploy
        super
      end

      def appserver_config
        'unicorn.conf'
      end

      def add_appserver_service_script
        opts = {
          deploy_dir: deploy_dir(app), app_shortname: app['shortname'], deploy_env: deploy_env
        }

        template_path = File.join(deploy_dir(app), File.join('shared', 'scripts', 'unicorn'))

        context.template template_path do
          owner node['deployer']['user']
          group node['deployer']['group']
          mode '0755'
          source 'unicorn_script.erb'
          variables opts
        end
      end
    end
  end
end
