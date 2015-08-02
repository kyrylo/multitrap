require 'spec_helper'

if Multitrap.jruby?
  SIGNAL = 'PIPE'
  OTHER_SIGNAL = 'TTIN'
else
  SIGNAL = 'USR1'
  OTHER_SIGNAL = 'USR2'
end

def sleep_2
  sleep 2 unless Multitrap.mri?
end

describe Multitrap::Trap do
  shared_examples 'trap syntax' do |method|
    it "allows setting multiple callbacks" do
      a = []

      3.times do |i|
        method.call(SIGNAL) { a << i }
      end

      Process.kill(SIGNAL, $$)
      wait_for(a).to eq([0, 1, 2])
    end
  end

  describe "the Signal.trap syntax" do
    include_examples 'trap syntax', Signal.method(:trap)
  end

  describe "the Kernel.trap syntax" do
    include_examples 'trap syntax', Kernel.method(:trap)
  end

  describe "the trap syntax" do
    include_examples 'trap syntax', method(:trap)
  end

  describe "#trap" do
    after do
      Multitrap::Trap.__clear_all_handlers!
    end

    it "unwinds recursive traps" do
      a = nil

      trap(SIGNAL) do
        a = 1
        trap(SIGNAL) do
          a = 2
          trap(SIGNAL) do
            a = 3
          end
        end
      end

      expect(a).to be_nil

      Process.kill(SIGNAL, $$)
      sleep_2
      wait_for(a).to eq(1)

      # JRuby doesn't support nested traps and calls only the first trap. The
      # nested traps are never invoked.
      unless Multitrap.jruby?
        wait_for(a).to eq(1)

        Process.kill(SIGNAL, $$)
        sleep_2
        wait_for(a).to eq(2)

        Process.kill(SIGNAL, $$)
        sleep_2
        wait_for(a).to eq(3)

        Process.kill(SIGNAL, $$)
        sleep_2
        wait_for(a).to eq(3)
      end
    end

    describe "the command parameter" do
      context "is random object" do
        let(:obj) { Object.new }

        if Multitrap.rbx?
          it "raises error" do
            expect { trap(SIGNAL, obj) }.
              to raise_error(ArgumentError, /Handler must respond to #call \(was Object\)/)
          end
        else
          it "sets the callback" do
            expect(trap(SIGNAL, obj)).to have_key(SIGNAL)
          end
        end
      end

      context "an object, which responds to #call" do
        after { $a = nil }

        it "sets the callback" do
          $a = 1

          klass = Class.new do
            def call(x)
              $a = 2
            end
          end

          trap(SIGNAL, klass.new)

          Process.kill(SIGNAL, $$)
          sleep_2
          expect($a).to eq(2)
        end
      end
    end

    unless Multitrap.jruby?
      it "maintains previously defined callbacks" do
        # RSpec has its own :INT handler and we should make sure it's not lost.
        c = nil

        prev_callback = trap('INT') { c = 123 }

        expect(prev_callback['INT'].size).to eq(2)
        expect(prev_callback['INT'].first.to_s).to match(%r{lib/rspec/core/runner.rb})
      end
    end

    it "returns a trap list" do
      # By default Ruby returns previously defined callback.
      expect(trap(SIGNAL, proc{})).to be_a Hash
    end

    it "supports the proc syntax" do
      d = []

      3.times do |i|
        trap(SIGNAL, proc { d << i })
      end

      Process.kill(SIGNAL, $$)
      wait_for(d).to eq([0, 1, 2])
    end

    it "ignores block if proc is given" do
      e = []

      3.times do |i|
        trap(SIGNAL, proc { e << i }) do
          e << i+100
        end
      end

      Process.kill(SIGNAL, $$)
      wait_for(e).to eq([0, 1, 2])
    end

    it "binds to multiple signals" do
      shared_int = []
      shared_info = []

      3.times do |i|
        trap(SIGNAL) { shared_int << i }
      end

      3.times do |i|
        trap(OTHER_SIGNAL) { shared_info << i+100 }
      end

      Process.kill(SIGNAL, $$)
      Process.kill(OTHER_SIGNAL, $$)

      wait_for(shared_int).to eq([0, 1, 2])
      wait_for(shared_info).to eq([100, 101, 102])
    end

    it "yields signal's number" do
      f = nil

      trap(SIGNAL) { |signo| f = signo }

      Process.kill(SIGNAL, $$)
      if Multitrap.jruby?
        sleep 1
        wait_for(f).to eq(13)
      else
        sleep 1 if Multitrap.rbx?
        wait_for(f).to eq(10)
      end
    end

    it "raises error if signal doesn't exist" do
      if Multitrap.jruby?
        expect(trap(:DONUTS) {}).to have_key('DONUTS')
      else
        expect { trap(:DONUTS) {} }.
          to raise_error(ArgumentError, /signal (?:SIG)?'?DONUTS'?\z/)
      end
    end

    it "raises error if signal is reserved" do
      msg = case RUBY_ENGINE
            when 'ruby' then "can't trap reserved signal: SIGILL"
            when 'jruby' then "malformed format string - %S"
            end

      if Multitrap.rbx?
        expect(trap(:ILL) {}).to have_key('ILL')
      else
        expect { trap(:ILL) {} }.to raise_error(ArgumentError, msg)
      end
    end

    it "raises error if invoked without arguments" do
      msg = case RUBY_ENGINE
            when 'rbx'
              "method 'trap': given 0, expected 2"
            when 'jruby'
              "wrong number of arguments (0 for 1)"
            else
              "wrong number of arguments (0 for 1..2)"
            end

      expect { trap }.to raise_error(ArgumentError, msg)
    end

    it "raises error if invoked without block" do
      msg = if Multitrap.rbx?
              # The real trap adds `nil` as a callback and doesn't raise.
              /Handler must respond to #call \(was NilClass\)/
            else
              /tried to create Proc object without a block/
            end
      expect { trap(SIGNAL) }.to raise_error(ArgumentError, msg)
    end
  end
end
