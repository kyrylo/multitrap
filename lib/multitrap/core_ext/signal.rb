if Multitrap.mri?
  Signal.singleton_class.__send__(:include, Multitrap::PatchedTrap)
end
