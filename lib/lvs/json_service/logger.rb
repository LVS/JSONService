module LVS
  module JsonService
    module Logger
      def self.debug(message)
        if const_defined?(:RAILS_DEFAULT_LOGGER)
          RAILS_DEFAULT_LOGGER.debug(message)
        end
      end
    end
  end
end