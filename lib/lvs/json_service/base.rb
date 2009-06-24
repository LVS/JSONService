require 'activesupport'
require 'net/https'
require 'lvs/json_service/request'

module LVS
  module JsonService
    class Base
      include ::LVS::JsonService::Request

      attr_accessor :fields

      protected

      class << self
        @site = ""
        @services = []
        @service_prefix = ""
        @field_prefix = ""
        @encrypted = false
        @auth_cert = ""
        @auth_key = ""
        @auth_key_pass = ""

        def encrypted=(value)
          @encrypted = value
        end
        
        def auth_cert=(value)
          @auth_cert = value
        end
        
        def auth_key=(value)
          @auth_key = value
        end
        
        def auth_key_pass=(value)
          @auth_key_pass = value
        end

        def agp_location=(value)
          @agp_location = value
        end
            
        def add_service(service)
          @services ||= []
          @services = @services << service
        end
        
        def service_prefix=(value)
          @service_prefix = value
        end
        
        def field_prefix=(value)
          @field_prefix = value
        end
        
        def site=(value)
          # value is containing AGP_LOCATION already sometimes:
          value.gsub!(/^#{AGP_LOCATION}/, '') if AGP_LOCATION && value.match(/#{AGP_LOCATION}/)
          agp = @agp_location ? @agp_location : AGP_LOCATION
          agp.gsub!(/\/$/, '')
          value.gsub!(/^\//, '')
          @site = (agp + '/' + value)
        end

        def debug(message)
          LVS::JsonService::Logger.debug " \033[1;4;32mLVS::JsonService\033[0m #{message}"
        end

        def require_ssl?
          (Module.const_defined?(:SSL_ENABLED) && SSL_ENABLED) || (Module.const_defined?(:SSL_DISABLED) && !SSL_DISABLED)
        end

        def define_service(name, service, options = {})
          service_name = name

          service_path = service.split('.')
          if service_path.size <= 2
            internal_service = service
            prefix = @service_prefix
          else
            internal_service = service_path[-2..-1].join('.')
            prefix = service_path[0..-3].join('.') + '.'
          end

          options[:encrypted]     = @encrypted if @encrypted
          options[:auth_cert]     = @auth_cert if @auth_cert
          options[:auth_key]      = @auth_key if @auth_key
          options[:auth_key_pass] = @auth_key_pass if @auth_key_pass
          
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
            result = self.run_remote_request(@site + prefix + internal_service, method_params, options)
            if flags && flags[:raw]
              result
            else
              self.parse_result(result)
            end
          end

          add_service(name)
        end

        def fake_service(name, json)
          (class<<self;self;end).send :define_method, name do |*args|
            self.parse_result(JSON.parse(json))
          end
          add_service(name)
        end

        def services
          @services
        end

        def parse_result(response)
          if response.is_a?(Array)
            response.map { |x| self.new(x) }
          else
            self.new(response)
          end
        end
        
      end

      def initialize(values = {})
        values.each_pair do |key, value|
          key = key.underscore
          new_instance_methods = "
            def #{key}
              @#{key}
            end
            def #{key}=(value)
              @#{key} = value
            end
          "

          # If the key starts with has_ create alias to has_ method removing has
          # and putting ? at the end
          if key =~ /^has_/
            temp_key = "#{key.gsub(/^has_/, '')}?"
            new_instance_methods << "
              def #{temp_key}
                @#{key}
              end
             "
           end

          self.instance_eval(new_instance_methods)

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