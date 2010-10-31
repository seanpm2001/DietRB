# MacRuby implementation of IRB.
#
# This file is covered by the Ruby license. See COPYING for more details.
# 
# Copyright (C) 2009-2010, Eloy Duran <eloy.de.enige@gmail.com>

require 'irb/formatter'
require 'irb/source'

module IRB
  class Context
    IGNORE_RESULT = :irb_ignore_result
    
    attr_reader :object, :binding, :line, :source
    attr_accessor :formatter
    
    def initialize(object, explicit_binding = nil)
      @object  = object
      @binding = explicit_binding || object.instance_eval { binding }
      @line    = 1
      clear_buffer
      
      @last_result_assigner = __evaluate__("_ = nil; proc { |val| _ = val }")
      @exception_assigner   = __evaluate__("e = exception = nil; proc { |ex| e = exception = ex }")
    end
    
    def __evaluate__(source, file = __FILE__, line = __LINE__)
      eval(source, @binding, file, line)
    end

    def to_s
      object_description = "`#{object.inspect}'"
      object_description = "of class `#{object.class.name}'" if object_description.length > 32
      "#<IRB::Context for object #{object_description}>"
    end
    alias_method :inspect, :to_s
    
    def evaluate(source)
      result = __evaluate__(source.to_s, '(irb)', @line - @source.buffer.size + 1)
      unless result == IGNORE_RESULT
        store_result(result)
        output(formatter.result(result))
        result
      end
    rescue Exception => e
      store_exception(e)
      output(formatter.exception(e))
    end
    
    # Returns whether or not the user wants to continue the current runloop.
    # This can only be done at a code block indentation level of 0.
    #
    # For instance, this will continue:
    #
    #   process_line("def foo") # => true
    #   process_line("quit") # => true
    #   process_line("end") # => true
    #
    # But at code block indentation level 0, `quit' means exit the runloop:
    #
    #   process_line("quit") # => false
    def process_line(line)
      reindented = formatter.add_input_to_context(self, line)
      #if reindented
        #driver.last_line_decreased_indentation_level(line)
      #end

      return false if @source.terminate?

      if @source.syntax_error?
        output(formatter.syntax_error(@line, @source.syntax_error))
        @source.pop
      elsif @source.code_block?
        evaluate(@source)
        clear_buffer
      end
      @line += 1
      
      true
    end
    
    def driver
      IRB::Driver.current
    end

    # Output is directed to the IRB::Driver.current driver’s output if a
    # current driver is available. Otherwise it’s simply printed to $stdout.
    def output(string)
      if driver = self.driver
        driver.output.puts(string)
      else
        puts(string)
      end
    end
    
    def prompt
      formatter.prompt(self)
    end
    
    def input_line(line)
      output(formatter.prompt(self) + line)
      process_line(line)
    end
    
    def formatter
      @formatter ||= IRB.formatter
    end
    
    def clear_buffer
      @source = Source.new
    end
    
    def store_result(result)
      @last_result_assigner.call(result)
    end
    
    def store_exception(exception)
      @exception_assigner.call(exception)
    end
  end
end
