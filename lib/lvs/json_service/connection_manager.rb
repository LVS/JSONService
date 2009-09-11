module LVS
  module JsonService
    class ConnectionManager
      def self.get_connection(host, port, options)
        @@connections ||= {}
        key = create_key(host, port, options)
        connection = @@connections[key]
        if connection.nil? || !connection.started?
          connection = create_connection(host, port, options)
          @@connections[key] = connection
        end
        connection
      end
      
      def self.reset_connection(host, port, options)
        @@connections ||= {}
        key = create_key(host, port, options)
        @@connections.delete(key)
      end

      def self.reset_all_connections
        @@connections = {}
      end
      
      def self.create_connection(host, port, options)
        http = Net::HTTP.new(host, port)
        if options[:encrypted]
          http.use_ssl = true
          # Self-signed certs give streams of "warning: peer certificate won't be verified in this SSL session"
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
          LVS::JsonService::Logger.debug "Using SSL"
          if options[:auth_cert]
            LVS::JsonService::Logger.debug "Using Auth"
            http.cert = OpenSSL::X509::Certificate.new(File.read(options[:auth_cert]))
            http.key = OpenSSL::PKey::RSA.new(File.read(options[:auth_key]), options[:auth_key_password])
          end
        end
      
        http.open_timeout = options[:timeout] || 1
        http.read_timeout = options[:timeout] || 1
        LVS::JsonService::Logger.debug "Connecting"
        http.start
        http
      end
      
      private
      
      def self.create_key(host, port, options)
        "#{host}:#{port}:#{options.to_s}"
      end
    end
  end
end