require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require File.dirname(__FILE__) + '/mock_net_http'

describe LVS::JsonService::ConnectionManager do
  before :each do
    LVS::JsonService::ConnectionManager.reset_all_connections
    Net::HTTP.stub!(:new).and_return {MockNetHttp.new}
  end

  it "should return a new HTTP object on the first call" do
    http = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    http.class.should eql(MockNetHttp)
  end

  it "should return an existing HTTP object on subsequent calls" do
    http = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    http_subsequent = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    http.should eql(http_subsequent)
  end

  it "should reset the connection to a new object if requested" do
    http = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    LVS::JsonService::ConnectionManager.reset_connection('www.google.com', 80, {})
    http_subsequent = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    http.should_not eql(http_subsequent)
  end

  it "should reset all connections to requested" do
    http_google            = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    http_yahoo             = LVS::JsonService::ConnectionManager.get_connection('www.yahoo.com', 80, {})
    
    LVS::JsonService::ConnectionManager.reset_all_connections
    
    http_google_subsequent = LVS::JsonService::ConnectionManager.get_connection('www.google.com', 80, {})
    http_yahoo_subsequent  = LVS::JsonService::ConnectionManager.get_connection('www.yahoo.com', 80, {})
    
    http_google.should_not eql(http_google_subsequent)
    http_yahoo.should_not eql(http_yahoo_subsequent)
  end

end