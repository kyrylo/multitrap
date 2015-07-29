module Kernel
  [self, singleton_class].each do |klass|
    klass.__send__(:include, Object::Multitrap::PatchedTrap)
  end
end
