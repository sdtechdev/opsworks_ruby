# frozen_string_literal: true

module LoadBalancing
  # @param action_type [String] RegisterTargets | DeregisterTargets
  def manage_targets(action_type)
    ruby_block "attach to ALB" do
      block do
        raise "alb_helper block not specified in layer JSON" if node[:alb_helper].nil?
        raise "Target group ARN not specified in layer JSON" if node[:alb_helper][:target_group_arn].nil?

        app = search(:aws_opsworks_app).first
        app_source = app['app_source']
        access_key_id = app_source['user']
        secret_access_key = app_source['password']
        stack = search('aws_opsworks_stack').first
        region = stack[:region]
        instance = search('aws_opsworks_instance', 'self:true').first
        ec2_instance_id = instance[:ec2_instance_id]
        instance_ids = [ec2_instance_id]
        target_group_arn = node[:alb_helper][:target_group_arn]
        service = 'elasticloadbalancing'
        host = "elasticloadbalancing.#{region}.amazonaws.com"
        endpoint = "https://#{host}"
        timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        date = timestamp[0, 8]

        parameters = {
          'Action' => action_type,
          'Version' => '2015-12-01',
          'TargetGroupArn' => target_group_arn
        }

        instance_ids.each_with_index do |id, index|
          parameters["Targets.member.#{index + 1}.Id"] = id
        end

        request_body = URI.encode_www_form(parameters)

        canonical_headers = "host:#{host}\nx-amz-date:#{timestamp}\n"
        signed_headers = 'host;x-amz-date'

        payload_hash = OpenSSL::Digest::SHA256.hexdigest(request_body)

        canonical_request = [
          'POST',
          '/',
          '',
          canonical_headers,
          signed_headers,
          payload_hash
        ].join("\n")

        algorithm = 'AWS4-HMAC-SHA256'
        credential_scope = "#{date}/#{region}/#{service}/aws4_request"
        string_to_sign = [
          algorithm,
          timestamp,
          credential_scope,
          OpenSSL::Digest::SHA256.hexdigest(canonical_request)
        ].join("\n")

        def hmac(key, data)
          OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)
        end

        date_key = hmac('AWS4' + secret_access_key, date)
        date_region_key = hmac(date_key, region)
        date_region_service_key = hmac(date_region_key, service)
        signing_key = hmac(date_region_service_key, 'aws4_request')
        signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), signing_key, string_to_sign)

        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'X-Amz-Date' => timestamp,
          'Authorization' => "#{algorithm} Credential=#{access_key_id}/#{credential_scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"
        }

        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = request_body

        response = http.request(request)

        Chef::Log.info("LoadBalancing #{action_type} operation result =#{response.body}")
      end
      action :run
    end
  end
end

::Chef::Recipe.send(:include, LoadBalancing)
