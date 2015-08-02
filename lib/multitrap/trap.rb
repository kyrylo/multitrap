module Multitrap
  class Trap
    OWN_MRI_FRAME = %r{/lib/multitrap/trap.rb:[0-9]{1,3}:in `block in store_trap'}

    OWN_RBX_FRAME = %r{/lib/multitrap/trap.rb:[0-9]{1,3}:in `store_trap'}

    TRAVIS_FRAME = %r{lib/jruby\.jar!/jruby/kernel/signal\.rb}

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
        # JRuby doesn't support nested traps.
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
         !default_handler?(prev_trap_handler) &&
         !default_handler_path?(prev_trap_handler)
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
        caller.any? { |stackframe| stackframe =~ OWN_RBX_FRAME }
      when 'jruby'
        if caller.any? { |s| s =~ TRAVIS_FRAME }
          caller.any? { |stackframe| stackframe =~ OWN_RBX_FRAME }
        else
          puts "TRAVIS"
          caller.any? { |stackframe| stackframe =~ OWN_MRI_FRAME }
        end
      else
        raise NotImplementedError, 'unsupported Ruby engine'
      end
    end

    def create_trap_list
      Hash.new { |h, k| h[k] = [] }
    end

    def default_handler?(prev)
      ['DEFAULT', 'SYSTEM_DEFAULT', 'IGNORE'].any? { |h| h == prev }
    end

    def default_handler_path?(prev)
      [%r{Proc:.+@kernel/loader\.rb:[0-9]{1,4}},
       %r{Proc:.+@uri:classloader:/jruby/kernel/signal.rb:[0-9]{1,4}}].any? do |h|
        h =~ prev.to_s
       end
    end
  end
end
