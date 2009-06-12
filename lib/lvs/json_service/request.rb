# To change this template, choose Tools | Templates and open the template in the
# editor.

module LVS
  module JsonService
    module Request
      def self.transmit_remote_request(service, args, options)
        # debugger
        uri = URI.parse(service)

        http = Net::HTTP.new(uri.host, uri.port)
        if options[:encrypted] && !SSL_DISABLED
          http.use_ssl = true
          if options[:auth_cert]
            http.cert = OpenSSL::X509::Certificate.new(File.read(options[:auth_cert]))
            http.key = OpenSSL::PKey::RSA.new(File.read(options[:auth_key]), options[:auth_key_password])
          end
        end

        params = { "object_request"=>"#{args.to_json}"}

        options[:timeout] ||= 1

        http.open_timeout = options[:timeout]
        http.read_timeout = options[:timeout]
        req = Net::HTTP::Post.new(uri.path)
        req.form_data = params

        retries = options[:retries] || 0
        retries += 1 # We always want to do it one more than the number of retries (the try before the retry)

        begin
          response = http.start {|connection|
            connection.request(req)
          }
        rescue Timeout::Error, Errno::ECONNREFUSED => e
          if e.is_a?(Timeout::Error)
            response = LVS::JsonService::TimeoutError.new("Backend failed to respond in time", 500, service, args)
          elsif e.is_a?(Errno::ECONNREFUSED)
            response = LVS::JsonService::BackendUnavailableError.new("Backend unavailable", 500, service, args)
            sleep(options[:timeout] * 1.5)
          end

          retries -= 1
          http.open_timeout = (options[:timeout] * 1.5)
          http.read_timeout = (options[:timeout] * 1.5)
          debug("Retrying #{service}") if retries
        end while (retries > 0 && response.is_a?(LVS::JsonService::TimeoutError))

        response
      end

      def self.run_remote_request(service, args, options = {})
        debug "run_remote_request('#{service}', #{args.to_json}"
        response = transmit_remote_request(service, args, options)
        if response.is_a? Net::HTTPNotFound
          raise LVS::JsonService::NotFoundError.new("404 Found for the service", 404, service, args)
        end
        if response.is_a?(LVS::JsonService::TimeoutError) || response.is_a?(LVS::JsonService::BackendUnavailableError)
          raise response
        end
        if response.body.size < 1024
          debug "Response: #{response.body.gsub(/\n/, '')}"
        else
          debug "Response Snippet: #{response.body.gsub(/\n/, '')[0..1024]}"
        end
        result = JSON.parse(response.body)
        if result.is_a?(Hash) && result.has_key?("PCode")
          raise LVS::JsonService::Error.new(result["message"], result["PCode"], service, args, self.parse_result(result))
        end
        result
      rescue Exception => e
        Rails.logger.error("JSON API CALL FAIL: #{service} - #{args.to_yaml} - #{e}")
        raise e
      end
    end
  end
end
