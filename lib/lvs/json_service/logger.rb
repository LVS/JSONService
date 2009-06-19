module LVS
  module JsonService
    module Logger
      def self.debug(message)
        message = "  \033[1;4;32mLVS::JsonService\033[0m #{message}"
        Rails.logger.debug(message)
      end
    end
  end
end