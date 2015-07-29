module Multitrap
  class Trap
    OWN_FRAME = %r{.+/lib/multitrap/trap.rb:[0-9]{1,3}:in `block in store_trap'}

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

      @original_trap.call(signal) do |signo|
        @trap_list[signal].each do |trap_handler|
          trap_handler.call(signo)
        end
      end

      @trap_list
    end

    private

    def recursion?
      caller.any? { |stackframe| stackframe =~ OWN_FRAME }
    end
  end
end
