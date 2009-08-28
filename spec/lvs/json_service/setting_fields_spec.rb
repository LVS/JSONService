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
  it "should return stored values as is without playing" do
    
    obj = TestServiceForFakingCall.details
    test_hash = {:abc => [1, 2, 3]}
    obj.status = test_hash
    obj.status.should eql(test_hash)
  end
  
end