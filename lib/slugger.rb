require 'dsl'
require 'fog'
require 'pry'
require 'foreman/cli_fix'
require 'foreman/export/base_fix'

module Slugger
end

require 'slugger/aws'
require 'slugger/foreman'
require 'slugger/build_cache'
require 'slugger/docker'
require 'slugger/deb'
require 'slugger/util'

module Slugger
  def setup(file = 'slugger.rb')
    git_sha rescue 'unknown'
    Slugger::Deb.instances
    Slugger::Docker.instances
    Slugger::Foreman.instances
    instance_eval(IO.read(file), file)
  end

  {
    :deb => Slugger::Deb,
    :docker => Slugger::Docker,
    :foreman => Slugger::Foreman
  }.each do |method, klass|
    define_method(method) do |sym, &block|
      klass.new!(:name => sym, &block)
    end
  end

  def git_sha
    @git_sha ||= Slugger::Util.git_sha
  end
  
  module_function :setup, :deb, :docker, :foreman, :git_sha
end

require 'slugger/rake_task'
