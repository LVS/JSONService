require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe LVS::JsonService::Base do
  it "should include Request" do
    LVS::JsonService::Base.ancestors.should include(LVS::JsonService::Request)
  end
  
  it "should ignore calls to missing methods if ignore_missing is true" do
    class IgnoreMissingExample < LVS::JsonService::Base
      self.ignore_missing = true
    end
    obj = IgnoreMissingExample.new
    obj.do_voodoo.should eql(nil)
  end
  
  it "should raise an exception on missing methods if ignore_missing is not set" do
    class RaiseOnMissingExample < LVS::JsonService::Base; end
    obj = RaiseOnMissingExample.new
    lambda {obj.do_voodoo}.should raise_error(NoMethodError)
  end
  
  it "should find camelCase attributes using camelCase or ruby_sytax" do
    class AttributeNames < LVS::JsonService::Base
      self.ignore_missing = true
      fake_service :call, '{"longMethodName":1}'
    end
    obj = AttributeNames.call
    obj.longMethodName.should eql(1)
    obj.long_method_name.should eql(1)
  end
  
end