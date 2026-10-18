require 'bundler/gem_tasks'
require 'rake/testtask'
require 'shellwords'

Rake::TestTask.new(:minitest) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

desc 'Run the test suite (padded_cell on CRuby, plain Minitest elsewhere)'
if RUBY_ENGINE == 'ruby'
  task :test do
    sh 'padded_cell', *Shellwords.split(ENV.fetch('TESTOPTS', ''))
  end
else
  task test: :minitest
end

desc 'Run tests'
task default: :test
