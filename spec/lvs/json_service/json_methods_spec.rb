require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

class TestServiceForFakingCall < LVS::JsonService::Base
  self.agp_location = "http://doesntmatter.anything"
  self.site = 'testjsonservices/'
  self.service_prefix = 'com.json.commands.'
  self.field_prefix = 'event_'

  fake_service :details, 
    '{"id":1, "status":"OK", "count":2, "startDate":1240498565709, "hasOwner":1, 
    "bets":[{"betAmount":123}, {"betAmount":456}],
    "startDate":1240498565709}'
end

describe LVS::JsonService::Base do
  it "should include an array of bets" do
    TestServiceForFakingCall.details(:num_results => 5).bets.should be_an(Array)
  end
  
  it "should have an id of 1" do
    TestServiceForFakingCall.details(:num_results => 5).id.should eql(1)
  end
  
  it "should have a first child in the bets array with a bet_amount parameter of 123" do
    TestServiceForFakingCall.details(:num_results => 5).bets.first.bet_amount.should eql(123)
  end
  
  it "should have a working question mark method for boolean field has_owner" do
    TestServiceForFakingCall.details(:num_results => 5).owner?.should be_true
  end
  
  it "should convert date columns to dates" do
    TestServiceForFakingCall.details.start_date.utc.to_s(:rfc822).should eql("Thu, 23 Apr 2009 14:56:05 +0000")
  end
end
