require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--pattern spec/**/*_spec.rb -f d'
end

task :default => :spec
