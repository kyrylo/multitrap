module Multitrap
  module PatchedTrap
    def self.included(mod)
      original_trap = mod.method(:trap)

      mod.instance_eval do
        define_method(:trap) do |*args, &block|
          if args.size < 1
            raise ArgumentError, "wrong number of arguments (0 for 1..2)"
          end

          if block.nil? && !args[1].instance_of?(Proc)
            raise ArgumentError, 'tried to create Proc object without a block'
          end

          Multitrap::Trap.trap(original_trap, *args, &block)
        end
      end
    end
  end
end
