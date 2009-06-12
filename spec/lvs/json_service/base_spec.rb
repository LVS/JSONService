require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe LVS::JsonService::Base do
  it "should include Request" do
    LVS::JsonService::Base.ancestors.should include(LVS::JsonService::Request)
  end
end