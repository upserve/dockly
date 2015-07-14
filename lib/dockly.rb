require 'dockly/util'
require 'dockly/util/tar'
require 'dockly/util/git'
require 'foreman/cli_fix'
require 'foreman/export/base_fix'
require 'rugged'
require 'aws-sdk'

module Dockly
  attr_reader :instance, :git_sha
  attr_writer :load_file

  autoload :Foreman, 'dockly/foreman'
  autoload :BashBuilder, 'dockly/bash_builder'
  autoload :BuildCache, 'dockly/build_cache'
  autoload :Docker, 'dockly/docker'
  autoload :Deb, 'dockly/deb'
  autoload :History, 'dockly/history'
  autoload :Rpm, 'dockly/rpm'
  autoload :S3Writer, 'dockly/s3_writer'
  autoload :TarDiff, 'dockly/tar_diff'
  autoload :VERSION, 'dockly/version'

  LOAD_FILE = 'dockly.rb'

  def load_file
    @load_file || LOAD_FILE
  end

  def inst
    @instance ||= load_inst
  end

  def load_inst
    setup.tap do |state|
      if File.exists?(load_file)
        instance_eval(IO.read(load_file), load_file)
      end
    end
  end

  def setup
    {
      :debs => Dockly::Deb.instances,
      :rpms => Dockly::Rpm.instances,
      :dockers => Dockly::Docker.instances,
      :foremans => Dockly::Foreman.instances
    }
  end

  {
    :deb => Dockly::Deb,
    :rpm => Dockly::Rpm,
    :docker => Dockly::Docker,
    :foreman => Dockly::Foreman
  }.each do |method, klass|
    define_method(method) do |sym, &block|
      if block.nil?
        inst[:"#{method}s"][sym]
      else
        klass.new!(:name => sym, &block)
      end
    end
  end

  [:debs, :rpms, :dockers, :foremans].each do |method|
    define_method(method) do
      inst[method]
    end
  end

  def git_sha
    @git_sha ||= Dockly::Util::Git.sha
  end

  def aws_region(region = nil)
    @aws_region = region unless region.nil?
    @aws_region || 'us-east-1'
  end

  def s3
    @s3 ||= Aws::S3::Client.new(region: aws_region)
  end

  module_function :inst, :load_inst, :setup, :load_file, :load_file=,
                  :deb,  :rpm,  :docker,  :foreman, :git_sha,
                  :debs, :rpms, :dockers, :foremans, :aws_region, :s3
end

require 'dockly/rake_task'
