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
      @mutex = Mutex.new
    end

    def recursion?
      frame = caller.find do |f|
        f =~ %r{multitrap/lib/multitrap\.rb.+`block in add_trap'}
      end

      true if frame
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

      @mutex.synchronize do
        if recursion?
          @traps[sig].pop
        else
          @traps[sig].push(prc || block)
        end
      end

      @old_trap.call(sig) do
        @traps[sig].each do |trap_handler|
          trap_handler.call(Signal.list[sig])
        end
      end

      @traps
    end
  end
end
