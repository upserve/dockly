require 'rake'
require 'dockly'

module Dockly::RakeHelper
  module_function

  def find_deb!(name)
    deb = Dockly.debs[name]
    raise "No deb named #{name}" if deb.nil?
    deb
  end

  def find_docker!(name)
    docker = Dockly.dockers[name]
    raise "No docker named #{name}" if docker.nil?
    docker
  end

  def find_rpm!(name)
    rpm = Dockly.rpms[name]
    raise "No rpm named #{name}" if rpm.nil?
    rpm
  end
end

namespace :dockly do
  task :load do
    raise "No #{Dockly.load_file} found!" unless File.exist?(Dockly.load_file)
    load Dockly.load_file
  end

  namespace :deb do
    task :prepare, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper.find_deb!(args[:name]).create_package!
    end

    task :upload, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper.find_deb!(args[:name]).upload_to_s3
    end

    task :copy, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper
        .find_deb!(args[:name])
        .copy_from_s3(Dockly::History.duplicate_build_sha[0..6])
    end

    task :build, [:name] => 'dockly:load' do |t, args|
      deb = Dockly::RakeHelper.find_deb!(args[:name])
      deb.build unless deb.exists?
    end
  end

  namespace :rpm do
    task :prepare, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper.find_rpm!(args[:name]).create_package!
    end

    task :upload, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper.find_rpm!(args[:name]).upload_to_s3
    end

    task :copy, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper
        .find_rpm!(args[:name])
        .copy_from_s3(Dockly::History.duplicate_build_sha[0..6])
    end

    task :build, [:name] => 'dockly:load' do |t, args|
      rpm = Dockly::RakeHelper.find_rpm!(args[:name])
      rpm.build unless rpm.exists?
    end
  end

  namespace :docker do
    task :prepare, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper.find_docker!(args[:name]).generate_build
    end

    task :upload, [:name] => 'dockly:load' do |t, args|
      docker = Dockly::RakeHelper.find_docker!(args[:name])
      docker.export_only unless docker.exists?
    end

    task :copy, [:name] => 'dockly:load' do |t, args|
      Dockly::RakeHelper
        .find_docker!(args[:name])
        .copy_from_s3(Dockly::History.duplicate_build_sha[0..6])
    end

    task :build, [:name] => 'dockly:load' do |t, args|
      docker = Dockly::RakeHelper.find_docker!(args[:name])
      docker.generate! unless docker.exists?
    end
  end

  task :prepare_all => 'dockly:load' do
    Dockly.debs.values.each do |deb|
      Rake::Task['dockly:deb:prepare'].execute(deb.name)
    end

    Dockly.rpms.values.each do |rpm|
      Rake::Task['dockly:rpm:prepare'].execute(rpm.name)
    end

    Dockly.dockers.values.each do |docker|
      Rake::Task['dockly:docker:prepare'].execute(docker.name)
    end
  end

  task :upload_all => 'dockly:load' do
    Dockly.debs.values.each do |deb|
      Rake::Task['dockly:deb:upload'].execute(deb.name)
    end

    Dockly.rpms.values.each do |rpm|
      Rake::Task['dockly:rpm:upload'].execute(rpm.name)
    end

    Dockly.dockers.values.each do |docker|
      Rake::Task['dockly:docker:upload'].execute(docker.name)
    end
  end

  task :build_all => 'dockly:load' do
    Dockly.debs.keys.each do |deb|
      Rake::Task['dockly:deb:build'].execute(Rake::TaskArguments.new([:name], [deb]))
    end

    Dockly.rpms.keys.each do |rpm|
      Rake::Task['dockly:rpm:build'].execute(Rake::TaskArguments.new([:name], [rpm]))
    end

    Dockly.dockers.keys.each do |docker|
      Rake::Task['dockly:docker:build'].execute(Rake::TaskArguments.new([:name], [docker]))
    end
  end

  task :copy_all => 'dockly:load' do
    Dockly.debs.keys.each do |deb|
      Rake::Task['dockly:deb:copy'].execute(Rake::TaskArguments.new([:name], [deb]))
    end

    Dockly.rpms.keys.each do |rpm|
      Rake::Task['dockly:rpm:copy'].execute(Rake::TaskArguments.new([:name], [rpm]))
    end

    Dockly.dockers.keys.each do |docker|
      Rake::Task['dockly:docker:copy'].execute(Rake::TaskArguments.new([:name], [docker]))
    end
  end

  task :build_or_copy_all do
    if Dockly::History.duplicate_build?
      Rake::Task['dockly:copy_all'].invoke
    else
      Rake::Task['dockly:build_all'].invoke
      Dockly::History.write_content_tag!
      Dockly::History.push_content_tag!
    end
  end
end
