# Copyright Swipely, Inc.  All rights reserved.

$LOAD_PATH.unshift( File.join( File.dirname(__FILE__), 'lib' ) )

require 'rake'
require 'dockly'
require 'rspec/core/rake_task'
require 'cane/rake_task'

task :default => [:spec, :quality]

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--tag ~docker' if ENV['CI']
end

Cane::RakeTask.new(:quality) do |cane|
  cane.canefile = '.cane'
  cane.abc_exclude = %w(TarDiff#process)
end
