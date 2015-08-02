module Multitrap
  class Trap
    OWN_MRI_FRAME = %r{/lib/multitrap/trap.rb:[0-9]{1,3}:in `block in store_trap'}

    OWN_RBX_FRAME = %r{/lib/multitrap/trap.rb:[0-9]{1,3}:in `store_trap'}

    RESERVED_SIGNALS = %w|BUS SEGV ILL FPE VTALRM|

    KNOWN_SIGNALS = Signal.list.keys - RESERVED_SIGNALS

    def self.trap(original_trap, *args, &block)
      @@multitrap ||= new(original_trap)

      signal = args[0]
      command = args[1]

      @@multitrap.store_trap(signal, command, &block)
    end

    def self.__clear_all_handlers!
      @@multitrap ||= nil
      @@multitrap && @@multitrap.__clear_all_handlers!
    end

    def initialize(original_trap)
      @original_trap = original_trap
      @trap_list = create_trap_list
    end

    def store_trap(signal, command, &block)
      signal = signal.to_s
      command ||= block

      if nested_trap?
        return if Multitrap.jruby?
        @trap_list[signal].pop
      end
      @trap_list[signal] << command

      prev_trap_handler = @original_trap.call(signal) do |signo|
        @trap_list[signal].each do |trap_handler|
          trap_handler.call(signo || Signal.list[signal])
        end
      end

      if !nested_trap? &&
         @trap_list[signal].size == 1 &&
         prev_trap_handler != 'DEFAULT' &&
         prev_trap_handler != 'SYSTEM_DEFAULT' &&
         prev_trap_handler != 'INGORE' &&
         prev_trap_handler.inspect !~ %r{Proc:.+@kernel/loader\.rb:[0-9]{1,4}} &&
         prev_trap_handler.inspect !~ %r{Proc:.+@uri:classloader:/jruby/kernel/signal.rb:[0-9]{1,4}}
        @trap_list[signal].unshift(prev_trap_handler)
      end

      @trap_list
    end

    def __clear_all_handlers!
      @trap_list.keys.select {|s| KNOWN_SIGNALS.include?(s) }.each do |signal|
        @original_trap.call(signal, 'DEFAULT')
      end

      @trap_list = create_trap_list
    end

    private

    define_method(:nested_trap?) do
      case RUBY_ENGINE
      when 'ruby'
        caller.any? { |stackframe| stackframe =~ OWN_MRI_FRAME }
      when 'rbx'
        caller.grep(OWN_RBX_FRAME).size > 1
      when 'jruby'
        # JRuby doesn't support nested traps.
        false
      else
        raise NotImplementedError, 'unsupported Ruby engine'
      end
    end

    def create_trap_list
      Hash.new { |h, k| h[k] = [] }
    end
  end
end
