module Kernel
  [self, singleton_class].each do |klass|
    klass.include Object::Multitrap::PatchedTrap
  end
end
