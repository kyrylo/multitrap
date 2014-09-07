require 'multitrap/version'

module Multitrap
  class Trap
    RESERVED_SIGNALS = {
      'BUS' => 10,
      'SEGV' => 11,
      'ILL' => 4,
      'FPE' => 8,
      'VTALRM' => 26
    }

    def self.trap(sig, prc, old_trap, &block)
      @multitrap ||= self.new(old_trap)
      @multitrap.add_trap(sig, prc, &block)
    end

    def initialize(old_trap)
      @old_trap = old_trap
      @traps = {}
    end

    def add_trap(sig, prc, &block)
      if RESERVED_SIGNALS.key?(sig)
        raise ArgumentError, "can't trap reserved signal SIG#{sig}"
      end

      unless Signal.list.key?(sig)
        raise ArgumentError, "unsupported signal SIG#{sig}"
      end

      prc ||= block

      if prc.nil?
        raise ArgumentError, "tried to create Proc object without a block"
      end

      @traps[sig] ||= []
      @traps[sig].push(prc || block)

      @old_trap.call(sig) do
        @traps[sig].each do |signal|
          signal.call(Signal.list[sig])
        end
      end

      @traps
    end
  end
end

module Signal
  class << self
    alias_method :old_trap, :trap
    protected :old_trap

    def trap(sig, prc = nil, &block)
      Multitrap::Trap.trap(sig, prc, method(:old_trap), &block)
    end
  end
end

module Kernel
  def trap(sig, prc = nil, &block)
    Signal.trap(sig, prc, &block)
  end
  module_function :trap
end
