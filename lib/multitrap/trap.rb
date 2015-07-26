module Multitrap
  class Trap
    RESERVED_SIGNALS = {
      'BUS' => 10,
      'SEGV' => 11,
      'ILL' => 4,
      'FPE' => 8,
      'VTALRM' => 26
    }

    def self.trap(signal, command, old_trap, &block)
      @multitrap ||= self.new(old_trap)
      @multitrap.add_trap(signal, command, &block)
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

    def add_trap(signal, command, &block)
      if RESERVED_SIGNALS.key?(signal)
        raise ArgumentError, "can't trap reserved signal SIG#{signal}"
      end

      unless Signal.list.key?(signal)
        raise ArgumentError, "unsupported signal SIG#{signal}"
      end

      command ||= block

      if command.nil?
        raise ArgumentError, "tried to create Proc object without a block"
      end

      @traps[signal] ||= []

      @mutex.synchronize do
        if recursion?
          @traps[signal].pop
        else
          @traps[signal].push(command || block)
        end
      end

      @old_trap.call(signal) do
        @traps[signal].each do |trap_handler|
          trap_handler.call(Signal.list[signal])
        end
      end

      @traps
    end
  end
end
