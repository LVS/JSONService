class MockNetHttp
  
  attr_accessor :connection
  
  def initialize(*args)
    @connection = mock(:connection)    
  end
  
  def start
    yield @connection if block_given?
  end  
    
  def method_missing(*args)
    return self
  end
    
end