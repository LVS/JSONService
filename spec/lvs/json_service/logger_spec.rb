require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')


describe LVS::JsonService::Logger do
  before :each do
  end

  describe "debug" do
    describe "with Rails.logger set" do
      before :each do
        @mock_logger = mock()
        
        if !defined?(Rails)
          class Rails
            class << self
              def logger=(value)
                @logger = value
              end
              def logger
                @logger
              end
            end
          end
        end
        
        Rails.logger = @mock_logger
      end

      it "should pass the message to Rails.logger" do
        message = "Some debug message"
        coloured_message = "  \033[1;4;32mLVS::JsonService\033[0m #{message}"
        @mock_logger.should_receive(:debug).with(coloured_message)
        LVS::JsonService::Logger.debug(message)
      end
    end

    describe "without Rails defined" do
      before :each do
        Object.send(:remove_const, :Rails)
      end

      it "should not raise an exception" do
        lambda {
          LVS::JsonService::Logger.debug("something")
        }.should_not raise_error(Exception)
      end
    end
  end
end
