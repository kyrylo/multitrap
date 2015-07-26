module Multitrap
  module PatchedTrap
    def self.included(mod)
      mod.instance_eval do
        define_method(:trap) do |*args|
          Multitrap::Trap.trap(mod.method(:trap), *args)
        end
      end
    end
  end
end
