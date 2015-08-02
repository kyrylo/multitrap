module Multitrap
  module PatchedTrap
    def self.included(mod)
      original_trap = Signal.method(:trap)

      mod.instance_eval do
        define_method(:trap) do |*args, &block|
          if args.size < 1
            if Multitrap.rbx?
              raise ArgumentError, "method 'trap': given 0, expected 2"
            elsif Multitrap.jruby?
              raise ArgumentError, "wrong number of arguments (0 for 1)"
            else
              raise ArgumentError, "wrong number of arguments (0 for 1..2)"
            end
          end

          if block.nil?
            if Multitrap.rbx? && !args[1].respond_to?(:call)
              raise ArgumentError, "Handler must respond to #call (was #{args[1].class})"
            elsif args[1].nil?
              raise ArgumentError, 'tried to create Proc object without a block'
            end
          end

          Multitrap::Trap.trap(original_trap, *args, &block)
        end
      end
    end
  end
end
