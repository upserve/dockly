require 'rubygems'
require 'dockly'
require 'clamp'

class Dockly::AbstractCommand < Clamp::Command
  option ['-F', '--file'], 'FILE', 'dockly file to read', :default => 'dockly.rb', :attribute_name => :file

  def execute
    if File.exist?(file)
      Dockly.load_file = file
    else
      raise 'Could not find a dockly file!'
    end
  end
end

class Dockly::BuildCommand < Dockly::AbstractCommand
  parameter 'PACKAGE', 'the name to build the package for', :attribute_name => :package_name
  option ['-f', '--force'], :flag, 'force the package build', :default => false, :attribute_name => :force

  def execute
    super
    if package = Dockly.debs[package_name.to_sym]
      if force? || !package.exists?
        package.build
      else
        puts "Package already exists!"
      end
    end
  end
end

class Dockly::ListCommand < Dockly::AbstractCommand
  def execute
    super
    Dockly.debs.each_with_index do |(name, package), index|
      puts "#{index + 1}. #{name}"
    end
  end
end

class Dockly::Cli < Dockly::AbstractCommand
  subcommand ['build', 'b'], 'Create package', Dockly::BuildCommand
  subcommand ['list', 'l'], 'List packages', Dockly::ListCommand
end

