require 'spec_helper'

describe Multitrap::Trap do
  describe "#trap" do
    describe "recursive" do
      it "unwinds the stack" do
        a = nil

        trap(:USR1) do
          trap(:USR1) { a = 42 }
        end

        Process.kill(:USR1, $$)
        expect(a).to be_nil

        Process.kill(:USR1, $$)
        expect(a).to eq(42)
      end
    end

    describe "the command parameter" do
      it "allows accepting only Procs" do
        # The original method accepts any object.
        expect { trap(:USR1, Object.new) }.
          to raise_error(ArgumentError, /tried to create Proc object without a block/)
      end
    end

    it "adds multiple callbacks" do
      b = []

      3.times do |i|
        trap('USR1') { b << i }
      end

      Process.kill('USR1', $$)

      expect(b).to eq([0, 1, 2])
    end

    it "maintains previously defined callbacks" do
      # RSpec has its own :INT handler and we should make sure it's not lost.
      c = nil

      prev_callback = trap('INT') { c = 123 }

      expect(prev_callback['INT'].size).to eq(2)
      expect(prev_callback['INT'].first.to_s).to match(%r{lib/rspec/core/runner.rb})
    end

    it "returns a trap list" do
      # By default Ruby returns previously defined callback.
      expect(trap(:USR1, proc{})).to be_a Hash
    end

    it "supports the proc syntax" do
      d = []

      3.times do |i|
        trap(:USR1, proc { d << i })
      end

      Process.kill(:USR1, $$)

      expect(d).to eq([0, 1, 2])
    end

    it "ignores block if proc is given" do
      e = []

      3.times do |i|
        trap(:USR1, proc { e << i }) do
          e << i+100
        end
      end

      Process.kill(:USR1, $$)

      expect(e).to eq([0, 1, 2])
    end

    it "binds to multiple signals" do
      shared_int = []
      shared_info = []

      3.times do |i|
        trap(:USR1) { shared_int << i }
      end

      3.times do |i|
        trap(:USR2) { shared_info << i+100 }
      end

      Process.kill(:USR1, $$)
      Process.kill(:USR2, $$)

      expect(shared_int).to eq([0, 1, 2])
      expect(shared_info).to eq([100, 101, 102])
    end

    it "yields signal's number" do
      f = nil

      trap(:USR1) { |signo| f = signo }

      Process.kill(:USR1, $$)

      expect(f).to eq(10)
    end

    it "raises error if signal doesn't exist" do
      expect { trap(:DONUTS) {} }.
        to raise_error(ArgumentError, /unsupported signal SIGDONUTS/)
    end

    it "raises error if signal is reserved" do
      expect { trap(:ILL) {} }.
        to raise_error(ArgumentError, /can't trap reserved signal: SIGILL/)
    end

    it "raises error if invoked without arguments" do
      expect { trap }.
        to raise_error(ArgumentError, /wrong number of arguments \(0 for 1..2\)/)
    end

    it "raises error if invoked without block" do
      expect { trap(:USR1) }.
        to raise_error(ArgumentError, /tried to create Proc object without a block/)
    end
  end
end
