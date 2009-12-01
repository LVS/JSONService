require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

EXPECTED_OUTPUT = <<EOF
TestStringOutput
  integer_value: 1
  string_value: "test"
  date_test_date: Tue Dec 01 12:04:41 +0000 2009
  has_boolean: true
  array_value: 
    [0] first_integer_value: 2
        first_string_value: "test2"
    [1] first_integer_value: 3
        first_string_value: "test3"
  hash_value:
    second_integer_value: 4
    second_string_value: "test4"
EOF

JSON_INPUT = <<EOF
{
  "integerValue":1, 
  "stringValue":"test",
  "dateTestDate": 1259669081000,
  "hasBoolean": 1,
  "arrayValue":[
    {"firstIntegerValue":2,
     "firstStringValue":"test2"},
    {"firstIntegerValue":3,
     "firstStringValue":"test3"}
  ],
  "hashValue":{
    "secondIntegerValue":4,
    "secondStringValue":"test4"
  }
}
EOF

class TestStringOutput < LVS::JsonService::Base
  fake_service :test, JSON_INPUT
end

describe LVS::JsonService::Base do
  context "String output of the object" do
    before :each do
      @output = TestStringOutput.test.to_s
      @output_lines = @output.split("\n")
      @expected_lines = EXPECTED_OUTPUT.split("\n")
    end
    
    it "should contain the class name at line 1" do
      @output_lines[0].match(/^TestStringOutput /).should_not be_nil
      @output_lines[0].match(/ 0x([0-9a-f]+)/).should_not be_nil
    end
    
    it "should contain the integer value at the top level" do
      @output_lines.grep("  integer_value: 1").size.should eql(1)
    end
    
    it "should contain the string value at the top level" do
      @output_lines.grep("  string_value: \"test\"").size.should eql(1)
    end
    
    it "should contain the date value at the top level" do
      @output_lines.grep("  date_test_date: Tue Dec 01 12:04:41 +0000 2009").size.should eql(1)
    end
    
    it "should contain a hash_value top level with two subordinate keys" do
      m = @output.match(/  hash_value:\n    second_integer_value: 4\n    second_string_value: "test4"/m)
      m.size.should eql(1)
    end
    
    it "should contain an array with 2 entries" do
      @output_lines.grep("  array_value: [").size.should eql(1)
      @output_lines.grep("    0:").size.should eql(1)
      @output_lines.grep("      first_string_value: \"test2\"").size.should eql(1)
      @output_lines.grep("      first_integer_value: 2").size.should eql(1)
      @output_lines.grep("    1:").size.should eql(1)
      @output_lines.grep("      first_string_value: \"test3\"").size.should eql(1)
      @output_lines.grep("      first_integer_value: 3").size.should eql(1)
      @output_lines.grep("  ]").size.should eql(1)
    end
    
    # it "should return a nice formatted string" do
    #   @output.should eql(EXPECTED_OUTPUT)
    # end
  end
end