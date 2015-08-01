module Multitrap
  module PatchedTrap
    def self.included(mod)
      original_trap = mod.method(:trap)

      mod.instance_eval do
        define_method(:trap) do |*args, &block|
          if args.size < 1
            if Multitrap.rbx?
              raise ArgumentError, "method 'trap': given 0, expected 2"
            else
              raise ArgumentError, "wrong number of arguments (0 for 1..2)"
            end
          end

          if block.nil? && !args[1].instance_of?(Proc)
            if Multitrap.rbx?
              raise ArgumentError, "Handler must respond to #call (was #{args[1].class})"
            else
              raise ArgumentError, 'tried to create Proc object without a block'
            end
          end

          Multitrap::Trap.trap(original_trap, *args, &block)
        end
      end
    end
  end
end
