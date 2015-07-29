module Multitrap
  class Trap
    OWN_MRI_FRAME = %r{.+/lib/multitrap/trap.rb:[0-9]{1,3}:in `block in store_trap'}

    OWN_RBX_FRAME = %r{.+/lib/multitrap/trap.rb:[0-9]{1,3}:in `store_trap'}

    OWN_JRUBY_FRAME = %r{.+/lib/multitrap/trap.rb:[0-9]{1,3}:in `block in store_trap'}

    def self.trap(original_trap, *args, &block)
      @@multitrap ||= new(original_trap)

      signal = args[0]
      command = args[1]

      @@multitrap.store_trap(signal, command, &block)
    end

    def initialize(original_trap)
      @original_trap = original_trap
      @trap_list = Hash.new { |h, k| h[k] = [] }
    end

    def store_trap(signal, command, &block)
      signal = signal.to_s
      command ||= block

      @trap_list[signal].pop if recursion?
      @trap_list[signal] << command

      prev_trap_handler = @original_trap.call(signal) do |signo|
        @trap_list[signal].each do |trap_handler|
          trap_handler.call(signo)
        end
      end

      if @trap_list[signal].size == 1 && prev_trap_handler != 'DEFAULT'
        @trap_list[signal].unshift(prev_trap_handler)
      end

      @trap_list
    end

    private

    def recursion?
      caller.any? do |stackframe|
        [OWN_MRI_FRAME, OWN_RBX_FRAME, OWN_JRUBY_FRAME].any? do |template|
          stackframe.match(template)
        end
      end
    end
  end
end
