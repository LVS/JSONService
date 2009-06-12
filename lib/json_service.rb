require 'activesupport'
require 'net/https'

module LVS
  module JsonService
    class Base
      @@services = []
      @@cache = CACHE if defined?(CACHE)
      @@service_prefix = ""
      attr_accessor :fields
      cattr_accessor :service_prefix
      cattr_accessor :field_prefix
      cattr_accessor :cache

      protected

      def self.site=(value)
        # value is containing AGP_LOCATION already sometimes:
        if SSL_DISABLED
          value.gsub!(/^#{AGP_LOCATION}/, '') if AGP_LOCATION && value.match(/#{AGP_LOCATION}/)
          agp = AGP_LOCATION.gsub(/\/$/, '')
        else
          value.gsub!(/^#{AGP_LOCATION}/, '')
          value.gsub!(/^#{SSL_AGP_LOCATION}/, '') if SSL_AGP_LOCATION && value.match(/#{SSL_AGP_LOCATION}/)
          agp = SSL_AGP_LOCATION.gsub(/\/$/, '')
        end
        value.gsub!(/^\//, '')
        @@site = (agp + '/' + value)
      end

      def self.debug(message)
        Rails.logger.debug " \033[1;4;32mLVS::JsonService\033[0m #{message}"
      end

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

      def self.define_cached_service(name, service, options)
        (class<<self;self;end).send :define_method, name do |*args|
          begin
            args = args.first || {}
            options[:cache_time] ||= 10
            service_name = "call_#{name}"
            mutex ||= Mutex::new
            tried = false
            mutex.lock if AppTools.is_memcached_threaded?
            begin
              jsn_data = { }
              if ActionController::Base.perform_caching && @@cache
                Rails.logger.info("JSON API CACHED CALL: #{service} - #{args.to_yaml}")
                key = "json:call:" + Digest::MD5.hexdigest("#{service}:#{args.to_s}")
                cached = @@cache.get(key)
                if cached.nil?
                  result = self.send(service_name, args)
                  @@cache.set(key, result, options[:cache_time])
                  jsn_data = result
                else
                  jsn_data = cached
                end
              else
                Rails.logger.info("JSON API CALL: #{method} - #{args.to_yaml}")
                jsn_data = self.send(service_name, args)
              end
              jsn_data
            rescue MemCache::MemCacheError => err
              raise err if tried
              Rails.logger.info("JSON API CALL RETRY: #{err} - #{method} - #{args.to_yaml}")
              tried = true
              retry
            end
          ensure
            mutex.unlock if AppTools.is_memcached_threaded?
          end
        end
      end

      def self.define_service(name, service, options = {})
        service_name = name

        service_path = service.split('.')
        if service_path.size <= 2
          internal_service = service
          prefix = @@service_prefix
        else
          internal_service = service_path[-2..-1].join('.')
          prefix = service_path[0..-3].join('.') + '.'
        end

        if options[:cached]
          service_name = "call_#{name}"
          self.define_cached_service(name, service, options)
        end

        (class<<self;self;end).send :define_method, service_name do |args|
          method_params, flags = args

          method_params ||= {}
          options[:defaults] ||= {}
          options[:defaults].each_pair do |key, value|
            method_params[key] = value if method_params[key].blank?
          end
          options[:required] ||= {}
          options[:required].each do |key|
            raise LVS::JsonService::Error.new("Required field #{key} wasn't supplied", internal_service, '0', method_params) if method_params[key].blank?
          end
          result = self.run_remote_request(@@site + prefix + internal_service, method_params, options)
          if flags && flags[:raw]
            result
          else
            self.parse_result(result)
          end
        end

        @@services << name
      end

      def self.fake_service(name, json)
        (class<<self;self;end).send :define_method, name do |*args|
          self.parse_result(JSON.parse(json))
        end
        @@services << name
      end

      def self.services
        @@services
      end

      def self.parse_result(response)
        if response.is_a?(Array)
          response.map { |x| self.new(x) }
        else
          self.new(response)
        end
      end

      def initialize(values = {})
        values.each_pair do |key, value|
          key = key.underscore
          self.class.send(:define_method, key, proc {self.instance_variable_get("@#{key}")})
          self.class.send(:define_method, "#{key}=", proc {|value| self.instance_variable_set("@#{key}", value)})

          # If the key starts with has_ create alias to has_ method removing has
          # and putting ? at the end
          if key =~ /^has_/
            temp_key = "#{key.gsub(/^has_/, '')}?"
            self.class.send(:define_method, temp_key, proc {self.instance_variable_get("@#{key}")})
            self.class.send(:define_method, "#{temp_key}=", proc {|value| self.instance_variable_set("@#{key}", value)})
          end

          if value.is_a?(Hash)
            self.instance_variable_set("@#{key}", self.class.new(value))
          elsif value.is_a?(Array)
            self.instance_variable_set("@#{key}", value.collect {|v| if v.is_a?(Hash) or v.is_a?(Array) then self.class.new(v) else v end })
          else
            if key =~ /date$/
              value = Time.at(value/1000)
            elsif key =~ /^has_/
              self.instance_variable_set("@#{key}", value)
              !(value == 0 || value.blank?)
            elsif key =~ /\?$/
              key = "has_#{key.chop}"
              !(value == 0 || value.blank?)
            end

            self.instance_variable_set("@#{key}", value)
          end
        end
      end

      def method_missing(*args)
        self.class.debug("Method #{args[0]} called on #{self.class} but is non-existant, returned default FALSE")
        super
      end
    end

    class Error < StandardError
      attr_reader :message, :code, :service, :args, :json_response

      def initialize(message, code, service, args, response=nil)
        @message = message
        @code   = code
        @service = service
        @args   = args
        @json_response = response

        super "#{message}\n#{service} (#{args.inspect})"
      end
    end

    class NotFoundError < Error; end
    class TimeoutError < Error; end
    class BackendUnavailableError < Error; end
  end
end