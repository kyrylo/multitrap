module Signal
  class << self
    alias_method :old_trap, :trap
    protected :old_trap

    def trap(sig, prc = nil, &block)
      Multitrap::Trap.trap(sig, prc, method(:old_trap), &block)
    end
  end
end
