# frozen_string_literal: true

require_relative 'lib/state_machines/yard/version'

Gem::Specification.new do |spec|
  spec.name = 'state_machines-yard'
  spec.version = StateMachines::Yard::VERSION
  spec.authors = ['Abdelkader Boudih', 'Aaron Pfeifer']
  spec.email = ['terminale@gmail.com']
  spec.summary = 'State machines YARD plugin'
  spec.description = 'State machines YARD plugin for automated documentation'
  spec.homepage = 'https://github.com/state-machines/state_machines-yard'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 4.0'

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ['lib']

  spec.add_dependency 'rdoc'
  spec.add_dependency 'state_machines', '>= 0.304.0'
  spec.add_dependency 'state_machines-diagram', '>= 0.4.0'
  spec.add_dependency 'yard'
  spec.add_development_dependency 'bundler', '>= 4.0'
  spec.add_development_dependency 'minitest', '~> 6.0'
  spec.add_development_dependency 'nokogiri'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.59'
  spec.add_development_dependency 'rubocop-minitest', '~> 0.34'
  spec.add_development_dependency 'rubocop-performance', '~> 1.20'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
