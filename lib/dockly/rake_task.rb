require 'rake'
require 'dockly'

$rake_task_logger = Dockly::Util::Logger.new('[dockly rake_task]', STDOUT, false)

if File.exist?('dockly.rb')
  Dockly.setup
end

class Rake::DebTask < Rake::Task
  def needed?
    raise "Package does not exist" if package.nil?
    !package.exists?
  end

  def package
    Dockly::Deb[name.split(':').last.to_sym]
  end
end

module Rake::DSL
  def deb(*args, &block)
    Rake::DebTask.define_task(*args, &block)
  end
end

namespace :dockly do
  task :load do
    raise "No dockly.rb found!" unless File.exist?('dockly.rb')
  end

  namespace :deb do
    Dockly::Deb.instances.values.each do |inst|
      deb inst.name => 'dockly:load' do |name|
        Thread.current[:rake_task] = name
        inst.build
      end
    end
  end
end
