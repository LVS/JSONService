module LVS
  module JsonService
    class ConnectionManager
      def self.get_connection(host, port, options)
        @@connections ||= {}
        key = create_key(host, port)
        connection = @@connections[key]
        if connection.nil? || !connection.started?
          connection = create_connection(host, port, options)
          @@connections[key] = connection
        end
        connection
      end
      
      def self.reset_connection(host, port, options)
        @@connections ||= {}
        key = create_key(host, port)
        begin
          LVS::JsonService::Logger.debug "Disconnecting from #{host}:#{port}"
          @@connections[key].finish if @@connections[key]
        rescue IOError
          # Do nothing
        end
        @@connections.delete(key)
      end

      def self.close_all_connections
        LVS::JsonService::Logger.debug "Requesting to close all (#{@@connections.size}) connections"
        @@connections.each do |key, connection|
          begin
            LVS::JsonService::Logger.debug "Disconnecting from #{host}:#{port}"
            connection.finish if connection
          rescue IOError
            # Do nothing
          end
        end
        reset_all_connections
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
      
        LVS::JsonService::Logger.debug "Connecting to #{host}:#{port}"
        http.start
        http
      end
      
      private
      
      def self.create_key(host, port)
        key = "#{host}:#{port}"
      end
    end
  end
end