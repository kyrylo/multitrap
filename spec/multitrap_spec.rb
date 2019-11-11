require 'spec_helper'

if Multitrap.jruby?
  SIGNAL = 'PIPE'
  OTHER_SIGNAL = 'TTIN'
else
  SIGNAL = 'USR1'
  OTHER_SIGNAL = 'USR2'
end

def sleep_
  sleep 2
end

describe Multitrap::Trap do
  shared_examples 'trap syntax' do |method|
    it "allows setting multiple callbacks" do
      a = []

      3.times do |i|
        method.call(SIGNAL) { a << i }
      end

      Process.kill(SIGNAL, $$)
      wait_for(a).to eq([2, 1, 0])
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
      sleep_
      wait_for(a).to eq(1)

      # JRuby doesn't support nested traps and calls only the first trap. The
      # nested traps are never invoked.
      if Multitrap.jruby?
        Process.kill(SIGNAL, $$)
        sleep_
        wait_for(a).to eq(1)
      else
        Process.kill(SIGNAL, $$)
        sleep_
        wait_for(a).to eq(2)

        Process.kill(SIGNAL, $$)
        sleep_
        wait_for(a).to eq(3)

        Process.kill(SIGNAL, $$)
        sleep_
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
          sleep_
          expect($a).to eq(2)
        end
      end
    end

    it "maintains previously defined callbacks" do
      c = nil

      callbacks = trap('INT') { c = 123 }

      # RSpec has its own :INT handler and we should make sure it's not lost.
      rspec_handler = callbacks['INT'].shift
      expect(callbacks['INT'].size).to eq(1)
      expect(rspec_handler.to_s).to match(%r{lib/rspec/core/runner.rb})

      Process.kill(:INT, $$)
      sleep_
      wait_for(c).to eq(123)

      callbacks['INT'].unshift(rspec_handler)
      expect(callbacks['INT'].size).to eq(2)
    end

    it "returns a trap list" do
      expect(trap(SIGNAL, proc{})).to be_a Hash
    end

    it "supports the proc syntax" do
      d = []

      3.times do |i|
        trap(SIGNAL, proc { d << i })
      end

      Process.kill(SIGNAL, $$)
      wait_for(d).to eq([2, 1, 0])
    end

    it 'ignores IGNORE trap commands' do
      e = []

      3.times do |_i|
        trap(SIGNAL, 'IGNORE')
      end

      Process.kill(SIGNAL, $$)
      wait_for(e).to eq([])
    end

    it "ignores block if proc is given" do
      e = []

      3.times do |i|
        trap(SIGNAL, proc { e << i }) { e << i+100 }
      end

      Process.kill(SIGNAL, $$)
      wait_for(e).to eq([2, 1, 0])
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

      wait_for(shared_int).to eq([2, 1, 0])
      wait_for(shared_info).to eq([102, 101, 100])
    end

    it "yields signal's number" do
      f = nil

      trap(SIGNAL) { |signo| f = signo }

      Process.kill(SIGNAL, $$)
      sleep_

      if Multitrap.jruby?
        wait_for(f).to eq(13)
      else
        wait_for(f).to eq(10)
      end
    end

    if Multitrap.jruby?
      it "defines the callback on unexisting signals" do
        expect(trap(:DONUTS) {}).to have_key('DONUTS')
      end
    else
      it "raises error if signal doesn't exist" do
        expect { trap(:DONUTS) {} }.
          to raise_error(ArgumentError, /signal (?:SIG)?'?DONUTS'?\z/)
      end
    end

    if Multitrap.rbx? || Multitrap.mri? && RUBY_VERSION =~ /\A1\.9\./
      it "defines the callback on reserved signals" do
        expect(trap(:ILL) {}).to have_key('ILL')
      end
    else
      it "raises error if signal is reserved" do
        msg = case RUBY_ENGINE
              when 'ruby' then "can't trap reserved signal: SIGILL"
              # This is a JRuby bug: https://github.com/jruby/jruby/issues/3208
              when 'jruby' then "malformed format string - %S"
              end

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
