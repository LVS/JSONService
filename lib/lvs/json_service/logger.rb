require 'pp'
module LVS
  module JsonService
    module Logger
      def self.debug(message)
        if defined?(Rails) && Rails.logger
          message = "  \033[1;4;32mLVS::JsonService\033[0m #{message}"
          Rails.logger.debug(message)
        end
      end
    end
  end
end