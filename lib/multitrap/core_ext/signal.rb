module Signal
  class << self
    alias_method :old_trap, :trap
    protected :old_trap

    def trap(signal, command = nil, &block)
      Multitrap::Trap.trap(signal, command, method(:old_trap), &block)
    end
  end
end
