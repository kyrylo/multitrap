require 'spec_helper'

if Multitrap.jruby?
  SIGNAL = :PIPE
  OTHER_SIGNAL = :TTIN
else
  SIGNAL = :USR1
  OTHER_SIGNAL = :USR2
end

describe Multitrap::Trap do
  describe "#trap" do
    after do
      Multitrap::Trap.__clear_all_handlers!
    end

    describe "recursive" do
      it "unwinds the stack" do
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
        sleep 2 unless Multitrap.mri?
        wait_for(a).to eq(1)

        # JRuby doesn't support nested traps and call only the first one. The
        # rest is ignored.
        unless Multitrap.jruby?
          wait_for(a).to eq(1)

          Process.kill(SIGNAL, $$)
          sleep 1 if Multitrap.jruby? || Multitrap.rbx?
          wait_for(a).to eq(2)

          Process.kill(SIGNAL, $$)
          wait_for(a).to eq(3)

          Process.kill(SIGNAL, $$)
          wait_for(a).to eq(3)
        end
      end
    end

    describe "the command parameter" do
      it "allows accepting only Procs" do
        expecting = expect { trap(SIGNAL, Object.new) }

        if Multitrap.rbx?
          expecting.
            to raise_error(ArgumentError, /Handler must respond to #call \(was Object\)/)
        else
          expecting.
            to raise_error(ArgumentError, /tried to create Proc object without a block/)
        end
      end
    end

    it "adds multiple callbacks" do
      b = []

      3.times do |i|
        trap(SIGNAL) { b << i }
      end

      Process.kill(SIGNAL, $$)
      wait_for(b).to eq([0, 1, 2])
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
      expect { trap }.
        to raise_error(
             ArgumentError,
             Multitrap.rbx? ? "method 'trap': given 0, expected 2" : /wrong number of arguments \(0 for 1..2\)/)
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
