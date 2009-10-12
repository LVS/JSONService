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
        @ignore_missing = false
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
          value.gsub!(/^#{AGP_LOCATION}/, '') if defined?(AGP_LOCATION) && value.match(/#{AGP_LOCATION}/)
          agp = @agp_location ? @agp_location : AGP_LOCATION
          agp.gsub!(/\/$/, '')
          value.gsub!(/^\//, '')
          @site = (agp + '/' + value)
        end
        
        def ignore_missing=(value)
          @ignore_missing = value
        end

        def ignore_missing
          @ignore_missing
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

        def fake_service(name, json, options = {})
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
            array = response.map { |x| self.new(x) }
          else
            self.new(response)
          end
        end
        
      end

      def initialize(values = {})
        @data = values
        @manually_set = {}
      end
      
      def id
        @data["id"]
      end
      
      def name_to_key(name)
        key = name.gsub(/[=?]/, '')
        key.camelize(:lower)
      end
      
      def respond_to?(name)
        name = name.to_s
        key = name_to_key(name)
        value = value_for_key(key)
        !value.nil?
      end
      
      def value_for_key(key)
        value = @data[key]
        if value.blank?
          key[0..0] = key[0..0].upcase # TODO: This feels like an awful hack, but having a day when nothing's working
          value = @data[key]
        end
        value
      end
      
      def method_missing(name, *args)
        name = name.to_s
        if name == "respond_to?" # don't know why this hack is necessary, but it is at the moment...
          return respond_to?(args[0])
        end
        key = name_to_key(name)
        value = value_for_key(key)
        if name =~ /=$/
          @data[key] = ManuallySetData.new(args[0])
          value = @data[key]
        elsif name =~ /\?$/
          value = @data[name_to_key("has_#{key}")]
          !(value == 0 || value.blank?)
        elsif name =~ /^has_/
          !(value == 0 || value.blank?)
        else
          if (value.is_a?(ManuallySetData))
            value = value.data
          elsif (value.is_a?(Hash))
            value = self.class.new(value)
          elsif (value.is_a?(Array))
            value = value.collect {|v| if v.is_a?(Hash) or v.is_a?(Array) then self.class.new(v) else v end }
          elsif name =~ /date$/
            value = Time.at(value/1000)
          end
        end
        if value.nil?
          if self.class.ignore_missing
            self.class.debug("Method #{name} called on #{self.class} but is non-existant, returned nil")
            return nil
          else
            raise NoMethodError.new("Method #{name} called on #{self.class} but is non-existant, returned nil")
          end
        end
        value
      end
    end

    class ManuallySetData
      attr_reader :data
      
      def initialize(value)
        @data = value
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
    class NotModified < Error; end
  end
end