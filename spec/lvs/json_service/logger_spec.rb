require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe LVS::JsonService::Logger do
  before :each do
  end

  describe "debug" do
    describe "with RAILS_DEFAULT_LOGGER set" do
      before :each do
        @mock_logger = mock()
        LVS::JsonService::Logger.const_set(:RAILS_DEFAULT_LOGGER, @mock_logger)
      end

      it "should pass the message to RAILS_DEFAULT_LOGGER" do
        message = "Some debug message"
        @mock_logger.should_receive(:debug).with(message)
        LVS::JsonService::Logger.debug(message)
      end
    end

    describe "without RAILS_ROOT set" do
      before :each do
        LVS::JsonService::Logger.module_eval do
          remove_const(:RAILS_DEFAULT_LOGGER) if const_defined?(:RAILS_DEFAULT_LOGGER)
        end
      end

      it "should not raise an exception" do
        lambda {
          LVS::JsonService::Logger.debug("something")
        }.should_not raise_error(Exception)
      end
    end
  end
end
