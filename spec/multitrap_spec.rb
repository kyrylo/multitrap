require 'spec_helper'

describe Multitrap::Trap do
  describe "#trap" do
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
        trap('INT', proc { shared << i }) do
          shared << i+100
        end
      end

      Process.kill('INT', $$)

      expect(shared).to eq([0, 1, 2])
    end

    it "binds to multiple signals" do
      shared_int = []
      shared_info = []

      3.times do |i|
        trap('INT') { shared_int << i }
      end

      3.times do |i|
        trap('INFO') { shared_info << i+100 }
      end

      Process.kill('INT', $$)
      Process.kill('INFO', $$)

      expect(shared_int).to eq([0, 1, 2])
      expect(shared_info).to eq([100, 101, 102])
    end

    it "yields signal's number" do
      number = nil

      trap('INT') { |signo| number = signo }

      Process.kill('INT', $$)

      expect(number).to eq(2)
    end

    it "raises ArgumentError if signal doesn't exist" do
      expect{
        trap('DONUTS') { }
      }.to raise_error(ArgumentError, /unsupported signal SIGDONUTS/)
    end

    it "raises ArgumentError if signal is reserved" do
      expect{
        trap('ILL') {}
      }.to raise_error(ArgumentError, /can't trap reserved signal SIGILL/)
    end
  end
end
