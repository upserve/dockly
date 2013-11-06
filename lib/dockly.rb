require 'dockly/util'
require 'fog'
require 'pry'
require 'foreman/cli_fix'
require 'foreman/export/base_fix'

module Dockly
end

require 'dockly/aws'
require 'dockly/foreman'
require 'dockly/build_cache'
require 'dockly/docker'
require 'dockly/deb'
require 'dockly/util/tar'
require 'dockly/util/git'

module Dockly
  def setup(file = 'dockly.rb')
    git_sha rescue 'unknown'
    Dockly::Deb.instances
    Dockly::Docker.instances
    Dockly::Foreman.instances
    instance_eval(IO.read(file), file)
  end

  {
    :deb => Dockly::Deb,
    :docker => Dockly::Docker,
    :foreman => Dockly::Foreman
  }.each do |method, klass|
    define_method(method) do |sym, &block|
      klass.new!(:name => sym, &block)
    end
  end

  def git_sha
    @git_sha ||= Dockly::Util::Git.git_sha
  end

  module_function :setup, :deb, :docker, :foreman, :git_sha
end

require 'dockly/rake_task'
