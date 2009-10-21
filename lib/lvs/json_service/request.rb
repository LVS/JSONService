require 'json'
require 'lvs/json_service/logger'
require 'lvs/json_service/connection_manager'

module LVS
  module JsonService
    module Request
      
      def self.included(base) # :nodoc:
        base.extend ClassMethods    
      end      
      
      module ClassMethods
        def unique_request_id
          Digest::SHA1.hexdigest((rand(4294967295)+Time.now.usec).to_s)
        end
        
        def http_request_with_timeout(service, args, options)
          uri = URI.parse(service)
        
          req = Net::HTTP::Post.new(uri.path)
          req.add_field("X-LVS-Request-ID", options[:request_id])
          
          req.form_data = { "object_request" => args.to_json }

          options[:encrypted] ||= require_ssl?
          retries = options[:retries] || 0
          hard_retries = 1 # For persistent connection failures

          begin
            retries -= 1
                    
            http = LVS::JsonService::ConnectionManager.get_connection(uri.host, uri.port, options)
            response = http.request(req)
          
          rescue Errno::EPIPE, EOFError, Errno::ECONNRESET, Errno::ECONNABORTED
            hard_retries -= 1
            if hard_retries >= 0
              sleep(1)
              LVS::JsonService::ConnectionManager.reset_connection(uri.host, uri.port, options)
              retry
            end
          
          rescue Timeout::Error => e
            if retries >= 0
              LVS::JsonService::Logger.debug(
                "Retrying #{service} due to TimeoutError"
              )
              retry
            end
            raise LVS::JsonService::TimeoutError.new("Backend failed to respond in time", 500, service, args)
                    
          rescue Errno::ECONNREFUSED => e
            if retries >= 0
              LVS::JsonService::Logger.debug(
                "Retrying #{service} due to Errno::ECONNREFUSED"
              )
              sleep(1)  
              retry
            end
            raise LVS::JsonService::BackendUnavailableError.new("Backend unavailable", 500, service, args)
            
          rescue OpenSSL::SSL::SSLError => e
            raise LVS::JsonService::BackendUnavailableError.new("Backend unavailable #{e}", 500, service, args)
            
          end

          if response.is_a?(Net::HTTPNotFound)
            raise LVS::JsonService::NotFoundError.new("404 Found for the service #{service}", 404, service, args)
          end

          if response.is_a?(Net::HTTPNotModified)
            raise LVS::JsonService::NotModified.new("304 Data hasn't changed", 304, service, args)
          end

          response
        end

        def run_remote_request(service, args, options = {})
          LVS::JsonService::Logger.debug "Requesting '#{service}' with #{args.to_json}"
          
          options[:request_id] = unique_request_id
          if options[:cached_for]
            timing = "CACHED"
            response, result = Rails.cache.fetch([service, args].cache_key, :expires_in => options[:cached_for]) do
              start = Time.now
              response = http_request_with_timeout(service, args, options)
              verify_request_id(response, options[:request_id])
              net_timing = ("%.1f" % ((Time.now - start) * 1000)) + "ms"
              start = Time.now
              result = JSON.parse(response.body)
              parse_timing = ("%.1f" % ((Time.now - start) * 1000)) + "ms"
              timing = "Net: #{net_timing}, Parse: #{parse_timing}"
              [response, result]
            end
          else
            start = Time.now
            response = http_request_with_timeout(service, args, options)
            verify_request_id(response, options[:request_id])
            net_timing = ("%.1f" % ((Time.now - start) * 1000)) + "ms"
            start = Time.now
            result = JSON.parse(response.body)
            parse_timing = ("%.1f" % ((Time.now - start) * 1000)) + "ms"
            timing = "Net: #{net_timing}, Parse: #{parse_timing}"
          end

          if response.body.size < 1024 || options[:debug]
            LVS::JsonService::Logger.debug "Response (#{timing}): #{response.body.gsub(/\n/, '')}"
          else
            LVS::JsonService::Logger.debug "Response Snippet (#{timing} / #{"%.1f" % (response.body.size/1024)}kB): #{response.body.gsub(/\n/, '')[0..1024]}"
          end
          if result.is_a?(Hash) && result.has_key?("PCode")
            raise LVS::JsonService::Error.new(result["message"], result["PCode"], service, args, result)
          end
          result
        end
        
        def verify_request_id(response, request_id)
          returned_request_id = response["X-LVS-Request-ID"]
          if returned_request_id != request_id && !returned_request_id.blank?
            raise LVS::JsonService::RequestMismatchError.new("The sent Request ID (#{request_id}) didn't " + 
              "match the returned Request ID (#{returned_request_id}) ")
          else
            LVS::JsonService::Logger.debug "Sent and received Request ID - #{request_id}"
          end
        end
      end
    end
  end
end
