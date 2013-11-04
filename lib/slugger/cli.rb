require 'rubygems'
require 'slugger'
require 'clamp'

class Slugger::AbstractCommand < Clamp::Command
  option ['-F', '--file'], 'FILE', 'slugger file to read', :default => 'slugger.rb', :attribute_name => :file

  def execute
    if File.exist?(file)
      Slugger.setup(file)
    else
      raise 'Could not find a slugger file!'
    end
  end
end

class Slugger::BuildCommand < Slugger::AbstractCommand
  parameter 'PACKAGE', 'the name to build the package for', :attribute_name => :package_name
  option ['-f', '--force'], :flag, 'force the package build', :default => false, :attribute_name => :force

  def execute
    super
    if package = Slugger::Deb.instances[package_name.to_sym]
      if force? || !package.exists?
        package.build
      else
        puts "Package already exists!"
      end
    end
  end
end

class Slugger::ListCommand < Slugger::AbstractCommand
  def execute
    super
    Slugger::Deb.instances.each_with_index do |(name, package), index|
      puts "#{index + 1}. #{name}"
    end
  end
end

class Slugger::Cli < Slugger::AbstractCommand
  subcommand ['build', 'b'], 'Create package', Slugger::BuildCommand
  subcommand ['list', 'l'], 'List packages', Slugger::ListCommand
end

