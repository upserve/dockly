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

class Dockly::BuildOrCopyAllCommand < Dockly::AbstractCommand
  def execute
    super
    Rake::Task["dockly:build_or_copy_all"].invoke
  end
end

class Dockly::BuildDebCommand < Dockly::AbstractCommand
  parameter 'PACKAGE', 'the name to build the package for', :attribute_name => :package_name
  option ['-n', '--no-export'], :flag, 'do not export', :default => false, :attribute_name => :noexport

  def execute
    super
    if Dockly.debs[package_name.to_sym]
      if noexport?
        Rake::Task["dockly:deb:prepare"].invoke(package_name)
      else
        Rake::Task["dockly:deb:build"].invoke(package_name)
      end
    end
  end
end

class Dockly::BuildRpmCommand < Dockly::AbstractCommand
  parameter 'PACKAGE', 'the name to build the package for', :attribute_name => :package_name
  option ['-n', '--no-export'], :flag, 'do not export', :default => false, :attribute_name => :noexport

  def execute
    super
    if Dockly.rpms[package_name.to_sym]
      if noexport?
        Rake::Task["dockly:rpm:prepare"].invoke(package_name)
      else
        Rake::Task["dockly:rpm:build"].invoke(package_name)
      end
    end
  end
end

class Dockly::DockerCommand < Dockly::AbstractCommand
  parameter 'DOCKER', 'the name to generate the docker image for', :attribute_name => :docker_name
  option ['-n', '--no-export'], :flag, 'do not export', :default => false, :attribute_name => :noexport

  def execute
    super
    if Dockly.dockers[docker_name.to_sym]
      if noexport?
        Rake::Task["dockly:docker:prepare"].invoke(docker_name)
      else
        Rake::Task["dockly:docker:build"].invoke(docker_name)
      end
    end
  end
end

class Dockly::ListCommand < Dockly::AbstractCommand
  def execute
    super
    dockers = Dockly.dockers.dup
    debs = Dockly.debs
    rpms = Dockly.rpms

    puts "Debs" unless debs.empty?
    debs.each_with_index do |(name, package), index|
      puts "#{index + 1}. #{name}"
      if package.docker
        dockers.delete(package.docker.name)
        puts " - Docker: #{package.docker.name}"
      end
    end

    puts "RPMs" unless rpms.empty?
    rpms.each_with_index do |(name, package), index|
      puts "#{index + 1}. #{name}"
      if package.docker
        dockers.delete(package.docker.name)
        puts " - Docker: #{package.docker.name}"
      end
    end

    puts "Dockers" unless dockers.empty?
    dockers.each_with_index do |(name, docker), index|
      puts "#{index + 1}. #{name}"
    end
  end
end

class Dockly::BuildCacheCommand < Dockly::AbstractCommand
  parameter 'DOCKER', 'the name of the docker image to build for', :attribute_name => :docker_name
  option ['-l', '--list'], :flag, 'list the build caches', :default => false, :attribute_name => :list
  option ['-L', '--local'], :flag, 'use local build caches', :default => false, :attribute_name => :local

  def execute
    Dockly::BuildCache.model = Dockly::BuildCache::Local
    super
    docker = Dockly.docker(docker_name.to_sym)
    build_caches = (docker && docker.build_cache) || []

    puts "No build cache for #{docker_name}" if build_caches.empty?

    if list?
      build_caches.each_with_index do |build_cache, index|
        puts "#{index + 1}. Hash: #{build_cache.hash_command} Build: #{build_cache.build_command}"
      end
    else
      bcs = if local?
        convert_bc_to_local_bc(docker)
      else
        build_caches
      end
      bcs.each do |bc|
        bc.execute!
      end
    end
  end
end

class Dockly::Cli < Dockly::AbstractCommand
  subcommand ['build-or-copy-all'], 'Run build or copy all Rake task', Dockly::BuildOrCopyAllCommand
  subcommand ['build', 'b'], 'Create deb package', Dockly::BuildDebCommand
  subcommand ['build-deb', 'bd'], 'Create deb package', Dockly::BuildDebCommand
  subcommand ['build-rpm', 'br'], 'Create RPM package', Dockly::BuildRpmCommand
  subcommand ['docker', 'd'], 'Generate docker image', Dockly::DockerCommand
  subcommand ['list', 'l'], 'List packages', Dockly::ListCommand
  subcommand ['build_cache', 'bc'], 'Build Cache commands', Dockly::BuildCacheCommand
end

def convert_bc_to_local_bc(docker)
  return [] unless docker
  lbcs = []
  docker.build_cache.each do |bc|
    lbc = Dockly::BuildCache::Local.new! { name bc.name }
    bc.instance_variables.each do |variable|
      lbc.instance_variable_set(variable, bc.instance_variable_get(variable))
    end
    lbcs << lbc
  end
  lbcs
end
