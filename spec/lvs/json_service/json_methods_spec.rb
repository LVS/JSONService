require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

class TestServiceForJsonMethodsCall < LVS::JsonService::Base
  self.agp_location = "http://doesntmatter.anything"
  self.site = 'testjsonservices/'
  self.service_prefix = 'com.json.commands.'
  self.field_prefix = 'event_'

  fake_service :details, 
    '{"id":1, "status":"OK", "count":2, "startDate":1240498565709, "hasOwner":1, 
    "bets":[{"betAmount":123}, {"betAmount":456}],
    "startDate":1240498565709, "with123":1}'
end

describe LVS::JsonService::Base do
  it "should include an array of bets" do
    TestServiceForJsonMethodsCall.details(:num_results => 5).bets.should be_an(Array)
  end
  
  it "should respond to bet_amount on the first element of the array of bets" do
    TestServiceForJsonMethodsCall.details(:num_results => 5).bets[0].respond_to?(:bet_amount).should be_true
  end
  
  it "should not respond to bet_other on the first element of the array of bets" do
    TestServiceForJsonMethodsCall.details(:num_results => 5).bets[0].respond_to?(:bet_other).should be_false
  end
  
  it "should have an id of 1" do
    TestServiceForJsonMethodsCall.details(:num_results => 5).id.should eql(1)
  end
  
  it "should have a first child in the bets array with a bet_amount parameter of 123" do
    TestServiceForJsonMethodsCall.details(:num_results => 5).bets.first.bet_amount.should eql(123)
  end
  
  it "should have a working question mark method for boolean field has_owner" do
    TestServiceForJsonMethodsCall.details(:num_results => 5).owner?.should be_true
  end
  
  it "should convert date columns to dates" do
    TestServiceForJsonMethodsCall.details.start_date.utc.to_s(:rfc822).should eql("Thu, 23 Apr 2009 14:56:05 +0000")
  end
  
  it "should recognise keys with integers in them" do
    TestServiceForJsonMethodsCall.details.with123.should eql(1)
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
