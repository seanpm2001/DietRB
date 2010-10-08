require File.expand_path('../spec_helper', __FILE__)
require 'tempfile'

main = self

describe "IRB::Context" do
  before do
    @context = IRB::Context.new(main)
  end
  
  it "initializes with an object and stores a copy of its binding" do
    @context.object.should == main
    eval("self", @context.binding).should == main
    eval("x = :ok", @context.binding)
    eval("y = x", @context.binding)
    eval("y", @context.binding).should == :ok
  end
  
  it "initializes with an 'empty' state" do
    @context.line.should == 1
    @context.source.should.be.instance_of IRB::Source
    @context.source.to_s.should == ""
  end
  
  it "does not use the same binding copy of the top level object" do
    lambda { eval("x", @context.binding) }.should.raise NameError
  end
  
  it "returns a prompt string, displaying line number and code indentation level" do
    @context.prompt.should == "irb(main):001:0> "
    @context.instance_variable_set(:@line, 23)
    @context.prompt.should == "irb(main):023:0> "
    @context.source << "def foo"
    @context.prompt.should == "irb(main):023:1> "
  end
  
  it "describes the context's object in the prompt" do
    @context.prompt.should == "irb(main):001:0> "
    o = Object.new
    IRB::Context.new(o).prompt.should == "irb(#{o.inspect}):001:0> "
  end
  
  it "returns a formatted exception message" do
    begin; DoesNotExist; rescue NameError => e; exception = e; end
    @context.format_exception(exception).should ==
      "NameError: uninitialized constant Bacon::Context::DoesNotExist\n\t#{exception.backtrace.join("\n\t")}"
  end
end

describe "IRB::Context, when evaluating source" do
  before do
    @context = IRB::Context.new(main)
    def @context.puts(string); @printed = string; end
  end
  
  it "evaluates code with the object's binding" do
    @context.evaluate("self").should == main
  end
  
  it "prints the result" do
    @context.evaluate("Hash[:foo, :foo]")
    printed = @context.instance_variable_get(:@printed)
    printed.should == "=> {:foo=>:foo}"
  end
  
  it "assigns the result to the local variable `_'" do
    result = @context.evaluate("Object.new")
    @context.evaluate("_").should == result
    @context.evaluate("_").should == result
  end
  
  it "coerces the given source to a string first" do
    o = Object.new
    def o.to_s; "self"; end
    @context.evaluate(o).should == main
  end
  
  it "rescues any type of exception" do
    lambda {
      @context.evaluate("DoesNotExist")
      @context.evaluate("raise Exception")
    }.should.not.raise
  end
  
  it "prints the exception that occurs" do
    @context.evaluate("DoesNotExist")
    printed = @context.instance_variable_get(:@printed)
    printed.should.match /^NameError: uninitialized constant DoesNotExist/
  end
end

class << Readline
  attr_reader :received
  
  def stub_input(*input)
    @input = input
  end
  
  def readline(prompt, history)
    @received = [prompt, history]
    @input.shift
  end
end

describe "IRB::Context, when receiving input" do
  before do
    @context = IRB::Context.new(main)
  end
  
  it "prints the prompt, reads a line, saves it to the history and returns it" do
    Readline.stub_input("def foo")
    @context.readline.should == "def foo"
    Readline.received.should == ["irb(main):001:0> ", true]
  end
  
  it "processes the output" do
    Readline.stub_input("def foo")
    def @context.process_line(line); @received = line; end
    @context.run
    @context.instance_variable_get(:@received).should == "def foo"
  end
  
  it "adds the received code to the source buffer" do
    @context.process_line("def foo")
    @context.process_line("p :ok")
    @context.source.to_s.should == "def foo\np :ok"
  end
  
  it "increases the current line number" do
    @context.line.should == 1
    @context.process_line("def foo")
    @context.line.should == 2
    @context.process_line("p :ok")
    @context.line.should == 3
  end
  
  it "evaluates the buffered source once it's a valid code block" do
    def @context.evaluate(source); @evaled = source; end
    
    @context.process_line("def foo")
    @context.process_line(":ok")
    @context.process_line("end; p foo")
    
    source = @context.instance_variable_get(:@evaled)
    source.to_s.should == "def foo\n:ok\nend; p foo"
  end
end