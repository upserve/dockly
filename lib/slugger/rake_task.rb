require 'rake'
require 'slugger'

$rake_task_logger = DSL::Logger.new('[slugger rake_task]', STDOUT, false)

Slugger.setup

class Rake::DebTask < Rake::Task
  def needed?
    raise "Package does not exist" if package.nil?
    !package.exists?
  end

  def package
    Slugger::Deb[name.split(':').last.to_sym]
  end
end

module Rake::DSL
  def deb(*args, &block)
    Rake::DebTask.define_task(*args, &block)
  end
end

namespace :slugger do
  task :load do
    raise "No slugger.rb found!" unless File.exist?('slugger.rb')
  end

  namespace :deb do
    Slugger::Deb.instances.values.each do |inst|
      deb inst.name => 'deployz:load' do |name|
        Thread.current[:rake_task] = name
        inst.build
      end
    end
  end
end
