# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_machines/yard/version'

Gem::Specification.new do |spec|
  spec.name = 'state_machines-yard'
  spec.version = StateMachines::Yard::VERSION
  spec.authors = ['Abdelkader Boudih', 'Aaron Pfeifer']
  spec.email = ['terminale@gmail.com']
  spec.summary = %q(State machines YARD plugin)
  spec.description = %q(State machines YARD plugin for automated documentation)
  spec.homepage = 'https://github.com/seuros/state_machines-yard'
  spec.license = 'MIT'

  spec.required_ruby_version     = '>= 1.9.3'

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ['lib']

  spec.add_dependency 'yard'
  spec.add_dependency 'state_machines-graphviz'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
