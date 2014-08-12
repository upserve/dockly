require 'rake'
require 'dockly'

class Rake::DebTask < Rake::Task
  def needed?
    raise "Package does not exist" if package.nil?
    !package.exists?
  end

  def package
    Dockly::Deb[name.split(':').last.to_sym]
  end
end

class Rake::RpmTask < Rake::Task
  def needed?
    raise "Package does not exist" if package.nil?
    !package.exists?
  end

  def package
    Dockly::Rpm[name.split(':').last.to_sym]
  end
end

class Rake::DockerTask < Rake::Task
  def needed?
    raise "Docker does not exist" if docker.nil?
    !docker.exists?
  end

  def docker
    Dockly::Docker[name.split(':').last.to_sym]
  end
end

module Rake::DSL
  def deb(*args, &block)
    Rake::DebTask.define_task(*args, &block)
  end

  def rpm(*args, &block)
    Rake::RpmTask.define_task(*args, &block)
  end

  def docker(*args, &block)
    Rake::DockerTask.define_task(*args, &block)
  end
end

namespace :dockly do
  task :load do
    raise "No dockly.rb found!" unless File.exist?('dockly.rb')
  end

  namespace :deb do
    Dockly.debs.values.each do |inst|
      deb inst.name => 'dockly:load' do |name|
        Thread.current[:rake_task] = name
        inst.build
      end
    end
  end

  namespace :rpm do
    Dockly.rpms.values.each do |inst|
      rpm inst.name => 'dockly:load' do |name|
        Thread.current[:rake_task] = name
        inst.build
      end
    end
  end

  namespace :docker do
    Dockly.dockers.values.each do |inst|
      docker inst.name => 'dockly:load' do
        Thread.current[:rake_task] = inst.name
        inst.generate!
      end

      namespace :noexport do
        task inst.name => 'dockly:load' do
          Thread.current[:rake_task] = inst.name
          inst.generate_build
        end
      end
    end
  end
end
