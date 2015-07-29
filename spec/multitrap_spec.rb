require 'spec_helper'

describe Multitrap::Trap do
  describe "#trap" do
    describe "recursive" do
      it "unwinds the stack" do
        number = nil

        trap(:INT) do
          trap(:INT) do
            number = 42
          end
        end

        Process.kill(:INT, $$)
        expect(number).to be_nil

        Process.kill(:INT, $$)
        expect(number).to eq(42)
      end
    end

    it "adds multiple callbacks" do
      shared = []

      3.times do |i|
        trap('INT') { shared << i }
      end

      Process.kill('INT', $$)

      expect(shared).to eq([0, 1, 2])
    end

    it "supports proc syntax" do
      shared = []

      3.times do |i|
        trap('INT', proc { shared << i })
      end

      Process.kill('INT', $$)

      expect(shared).to eq([0, 1, 2])
    end

    it "ignores block if proc is given" do
      shared = []

      3.times do |i|
        trap(:INT, proc { shared << i }) do
          shared << i+100
        end
      end

      Process.kill(:INT, $$)

      expect(shared).to eq([0, 1, 2])
    end

    it "binds to multiple signals" do
      shared_int = []
      shared_info = []

      3.times do |i|
        trap(:INT) { shared_int << i }
      end

      3.times do |i|
        trap(:WINCH) { shared_info << i+100 }
      end

      Process.kill(:INT, $$)
      Process.kill(:WINCH, $$)

      expect(shared_int).to eq([0, 1, 2])
      expect(shared_info).to eq([100, 101, 102])
    end

    it "yields signal's number" do
      number = nil

      trap(:INT) { |signo| number = signo }

      Process.kill(:INT, $$)

      expect(number).to eq(2)
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
      expect { trap(:INT) }.
        to raise_error(ArgumentError, /tried to create Proc object without a block/)
    end
  end
end
