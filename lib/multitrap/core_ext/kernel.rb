module Kernel
  def trap(sig, prc = nil, &block)
    Signal.trap(sig, prc, &block)
  end
  module_function :trap
end
