module Kernel
  def trap(signal, command = nil, &block)
    Signal.trap(signal, command, &block)
  end
  module_function :trap
end
