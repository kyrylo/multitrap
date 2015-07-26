Gem::Specification.new do |s|
  s.name         = 'multitrap'
  s.version      = File.read('VERSION')
  s.date         = Time.now.strftime('%Y-%m-%d')
  s.summary      = %q{Allows Signal.trap to have multiple callbacks}
  s.author       = 'Kyrylo Silin'
  s.email        = 'silin@kyrylo.org'
  s.homepage     = 'https://github.com/kyrylo/multitrap'
  s.licenses     = 'Zlib'

  s.require_path = 'lib'
  s.files        = %w[
    lib/multitrap/core_ext/signal
    lib/multitrap/core_ext/kernel
    lib/multitrap/trap
  ]
  s.test_files   = spec.files.grep(%r{^(test|spec|features)/})

  s.add_development_dependency 'bundler', '~> 1.9'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'pry'
end
