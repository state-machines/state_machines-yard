require_relative 'lib/state_machines/yard/version'

Gem::Specification.new do |spec|
  spec.name = 'state_machines-yard'
  spec.version = StateMachines::Yard::VERSION
  spec.authors = ['Abdelkader Boudih', 'Aaron Pfeifer']
  spec.email = ['terminale@gmail.com']
  spec.summary = %q(State machines YARD plugin)
  spec.description = %q(State machines YARD plugin for automated documentation)
  spec.homepage = 'https://github.com/state-machines/state_machines-yard'
  spec.license = 'MIT'

  spec.required_ruby_version     = '>= 3.0'

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ['lib']

  spec.add_dependency 'yard'
  spec.add_dependency 'state_machines-graphviz'
  spec.add_dependency 'rdoc'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'nokogiri'
end
