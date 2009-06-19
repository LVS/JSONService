module LVS
  module JsonService
    module Logger
      def self.debug(message)
        if const_defined?(:RAILS_DEFAULT_LOGGER)
          message = "  \033[1;4;32mLVS::JsonService\033[0m #{message}"
          RAILS_DEFAULT_LOGGER.debug(message)
        end
      end
    end
  end
end