require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

# Explicitly requiring this now to ensure it is loaded before we try to
# unmarshall response from the yaml fixture file.
require 'net/http'

describe LVS::JsonService::Request do
  before :each do
    @domain = "example.com"
    @path   = "/some/path"
    @port   = 80
    @url    = "http://#{@domain}#{@path}"

    @args   = {:some => "thing"}
    @options= {:timeout => 100}
  end
  
  describe ".http_request_with_timeout" do
    before :each do 
      @mock_post = mock(:post, :null_object => true)
      Net::HTTP::Post.stub!(:new).and_return(@mock_post)
      
      @mock_http = MockNetHttp.new
      @connection = @mock_http.connection
      Net::HTTP.stub!(:new).and_return(@mock_http)      
    end
    
    it "should set Net::HTTP#open_timeout" do
      @mock_http.should_receive(:open_timeout=).with(@options[:timeout])
      do_request      
    end
    
    it "should set Net::HTTP#read_timeout" do
      @mock_http.should_receive(:read_timeout=).with(@options[:timeout])      
      do_request      
    end    
    
    it "should default to a timeout of 1 if not set" do
      @options = {:timeout => nil}
      @mock_http.should_receive(:read_timeout=).with(1)     
      do_request
    end
    
    it "should pass through the domain and port to Net::HTTP" do
      Net::HTTP.should_receive(:new).with(@domain, @port).and_return(@mock_http)
      do_request
    end
    
    it "should create a Net::HTTP::Post object" do
      Net::HTTP::Post.should_receive(:new).with(@path).and_return(@mock_post)
      do_request
    end
    
    it "should assign the JSON parameters to a Net::HTTP::Post object" do
      @mock_post.should_receive(:form_data=).with({ "object_request" => @args.to_json })
      do_request
    end
    
    it "should send one request to Net::HTTP#start" do
      @connection.should_receive(:request).once.with(@mock_post)
      do_request
    end
    
    it "should return the response from the service" do
      response = "some response"
      @connection.should_receive(:request).and_return(response)
      do_request.should == response
    end
    
    describe "with 2 retries of Timeout::Error" do
      
      before :each do
        @options = {:retries => 2}
      end

      describe "with subsequent success" do

        it "should post the request 2 times" do
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered.and_raise(Timeout::Error.new(nil))                
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered
          do_request                
        end   
        
        it "should return the response from the service" do
          response = "some response"
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered.and_raise(Timeout::Error.new(nil))                
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered.and_return(response)
          do_request.should == response          
        end
        
      end
            
      it "should log the retry attempt" do
        @connection.stub!(:request).and_raise(Timeout::Error.new(nil))
        LVS::JsonService::Logger.should_receive(:debug).at_least(1).times.
          with("Retrying #{@url} due to TimeoutError")
        do_request_catching_errors
      end
      
      describe "with subseqent failure" do

        before :each do
          @connection.stub!(:request).and_raise(Timeout::Error.new(nil))
        end

        it "should post the request 3 times (original + 2 retries)" do
          @connection.should_receive(:request).with(@mock_post).exactly(3).times.and_raise(Timeout::Error.new(nil))        
          do_request_catching_errors
        end

        it "should raise an LVS::JsonService::TimeoutError exception" do
          lambda {
            do_request
          }.should raise_error(LVS::JsonService::TimeoutError)
        end
      end
        
    end
    
    describe "with 2 retries of Errno::ECONNREFUSED" do
      
      before :each do
        @options = {:retries => 2}
        ClassWithRequest.stub!(:sleep)                  
      end
      
      it "should sleep for 1 second before each timeout" do
        @connection.stub!(:request).and_raise(Errno::ECONNREFUSED)        
        ClassWithRequest.should_receive(:sleep).with(1)
        do_request_catching_errors
      end
      
      describe "with subsequent success" do

        it "should post the request 2 times" do
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered.and_raise(Errno::ECONNREFUSED)                
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered
          do_request                
        end   
        
        it "should return the response from the service" do
          response = "some response"
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered.and_raise(Errno::ECONNREFUSED)                
          @connection.should_receive(:request).with(@mock_post).exactly(1).times.ordered.and_return(response)
          do_request.should == response
        end
      end

      describe "with subsequent failure" do
        
        before :each do
          @connection.stub!(:request).and_raise(Errno::ECONNREFUSED)      
        end        
        
        it "should post the request 3 times (original + 2 retries)" do
          @connection.should_receive(:request).with(@mock_post).exactly(3).times.and_raise(Errno::ECONNREFUSED)        
          do_request_catching_errors
        end      

        it "should raise an LVS::JsonService::BackendUnavailableError exception" do
          lambda {
            do_request
          }.should raise_error(LVS::JsonService::BackendUnavailableError)
        end

      end

      it "should log the retry attempt" do
        @connection.stub!(:request).and_raise(Errno::ECONNREFUSED)
        LVS::JsonService::Logger.should_receive(:debug).at_least(1).times.
          with("Retrying #{@url} due to Errno::ECONNREFUSED")
        do_request_catching_errors
      end
    end

    it "should raise LVS::JsonService::NotFoundError if Net::HTTPNotFound is raised" do
      @connection.stub!(:request).and_return(Net::HTTPNotFound.new(404, 1.1, "Not Found"))
      lambda {
        do_request
      }.should raise_error(LVS::JsonService::NotFoundError)
    end
    
    it "should raise LVS::JsonService::NotModified if HTTPNotModified is raised" do
      @connection.stub!(:request).and_return(Net::HTTPNotModified.new(304, 1.1, "Not Modified"))
      lambda {
        do_request
      }.should raise_error(LVS::JsonService::NotModified)
    end
    
    def do_request
      ClassWithRequest.http_request_with_timeout(@url, @args, @options)
    end
    
    def do_request_catching_errors
      do_request
    rescue LVS::JsonService::Error
    end
    
  end

  describe ".run_remote_request" do
    before :each do
      @response = load_fixture('response.yml')
    end

    it "should call http_request_with_timeout with service, args and options" do
      ClassWithRequest.should_receive(:http_request_with_timeout).
        with(@url, @args, @options).
        and_return(@response)
      ClassWithRequest.run_remote_request(@url, @args, @options)
    end

    it "should return the parsed JSON result" do
      expected_result = [
        {"id"=>1100, "description"=>"Handball (ABP)"},
        {"id"=>978400, "description"=>"Casino Roulette"}
      ]
      ClassWithRequest.stub!(:http_request_with_timeout).and_return(@response)
      ClassWithRequest.run_remote_request(@url, @args, @options).should == expected_result
    end

    it "should raise an error if the response contains PCode" do
      error_response = load_fixture('error_response.yml')
      ClassWithRequest.stub!(:http_request_with_timeout).
        and_return(error_response)

      lambda {
        ClassWithRequest.run_remote_request(@url, @args, @options)
      }.should raise_error(LVS::JsonService::Error)
    end
  end
  
end

def load_fixture (file)
  response_file = File.join(File.dirname(__FILE__), '..', '..', 'fixtures', file)
  YAML.load_file(response_file)
end

class MockNetHttp
  
  attr_accessor :connection
  
  def initialize(*args)
    @connection = mock(:connection)    
  end
  
  def start
    yield @connection
  end  
    
  def method_missing(*args)
    return self
  end
    
end

class ClassWithRequest
  include LVS::JsonService::Request
  
  def self.require_ssl?
    false
  end
end

