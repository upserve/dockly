require 'fpm'

class Dockly::Deb
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  logger_prefix '[dockly deb]'
  dsl_attribute :package_name, :version, :release, :arch, :build_dir,
                :deb_build_dir, :pre_install, :post_install, :pre_uninstall,
                :post_uninstall, :s3_bucket, :files, :app_user, :vendor

  dsl_class_attribute :docker, Dockly::Docker
  dsl_class_attribute :foreman, Dockly::Foreman

  default_value :version, '0.0'
  default_value :release, '0'
  default_value :arch, 'x86_64'
  default_value :build_dir, 'build'
  default_value :deb_build_dir, 'deb'
  default_value :files, []
  default_value :app_user, 'nobody'
  default_value :vendor, 'Dockly'

  def file(source, destination)
    @files << { :source => source, :destination => destination }
  end

  def create_package!
    ensure_present! :build_dir, :deb_build_dir
    FileUtils.mkdir_p(File.join(build_dir, deb_build_dir))
    FileUtils.rm(build_path) if File.exist?(build_path)
    debug "exporting #{package_name} to #{build_path}"
    build_package
    if @deb_package
      @deb_package.output(build_path)
      info "exported #{package_name} to #{build_path}"
    end
  ensure
    @dir_package.cleanup if @dir_package
    @deb_package.cleanup if @deb_package
  end

  def build
    info "creating package"
    create_package!
    info "uploading to s3"
    upload_to_s3
  end

  def build_path
    ensure_present! :build_dir, :deb_build_dir
    File.join(build_dir, deb_build_dir, output_filename)
  end

  def exists?
    debug "#{name}: checking for package: #{s3_url}"
    Dockly::AWS.s3.head_object(s3_bucket, s3_object_name)
    info "#{name}: found package: #{s3_url}"
    true
  rescue
    info "#{name}: could not find package: " +
         "#{s3_url}"
    false
  end

  def upload_to_s3
    return if s3_bucket.nil?
    raise "Package wasn't created!" unless File.exist?(build_path)
    info "uploading package to s3"
    Dockly::AWS.s3.put_bucket(s3_bucket) rescue nil
    Dockly::AWS.s3.put_object(s3_bucket, s3_object_name, File.new(build_path))
  end

  def s3_url
    "s3://#{s3_bucket}/#{s3_object_name}"
  end

  def s3_object_name
    "#{package_name}/#{Dockly::Util::Git.git_sha}/#{output_filename}"
  end

  def output_filename
    "#{package_name}_#{version}.#{release}_#{arch}.deb"
  end

  def startup_script
    scripts = []
    bb = Dockly::BashBuilder.new
    scripts << bb.normalize_for_dockly
    scripts << bb.get_and_install_deb(s3_url, "/opt/dockly/#{File.basename(s3_url)}")

    scripts.join("\n")
  end

private
  def build_package
    ensure_present! :package_name, :version, :release, :arch

    info "building #{package_name}"
    @dir_package = FPM::Package::Dir.new
    add_foreman(@dir_package)
    add_files(@dir_package)
    add_docker_auth_config(@dir_package)
    add_docker(@dir_package)
    add_startup_script(@dir_package)

    convert_package

    @deb_package.scripts[:before_install] = pre_install
    @deb_package.scripts[:after_install] = post_install
    @deb_package.scripts[:before_remove] = pre_uninstall
    @deb_package.scripts[:after_remove] = post_uninstall

    @deb_package.name = package_name
    @deb_package.version = version
    @deb_package.iteration = release
    @deb_package.architecture = arch
    @deb_package.vendor = vendor


    info "done building #{package_name}"
  end

  def convert_package
    debug "converting to deb"
    @deb_package = @dir_package.convert(FPM::Package::Deb)
  end

  def add_foreman(package)
    return if foreman.nil?
    info "adding foreman export"
    foreman.create!
    package.attributes[:prefix] = foreman.init_dir
    Dir.chdir(foreman.build_dir) do
      package.input('.')
    end
    package.attributes[:prefix] = nil
  end

  def add_files(package)
    return if files.empty?
    info "adding files to package"
    files.each do |file|
      package.attributes[:prefix] = file[:destination]
      Dir.chdir(File.dirname(file[:source])) do
        package.input(File.basename(file[:source]))
      end
      package.attributes[:prefix] = nil
    end
  end

  def add_docker_auth_config(package)
    return if (registry = get_registry).nil? || !registry.authentication_required?
    info "adding docker config file"
    registry.generate_config_file!

    package.attributes[:prefix] = registry.auth_config_file || "~#{app_user}"
    Dir.chdir(File.dirname(registry.config_file)) do
      package.input(File.basename(registry.config_file))
    end
    package.attributes[:prefix] = nil
  end

  def add_docker(package)
    return if docker.nil? || docker.s3_bucket
    info "adding docker image"
    docker.generate!
    return unless docker.registry.nil?
    package.attributes[:prefix] = docker.package_dir
    Dir.chdir(File.dirname(docker.tar_path)) do
      package.input(File.basename(docker.tar_path))
    end
    package.attributes[:prefix] = nil
  end

  def get_registry
    if docker && registry = docker.registry
      registry
    end
  end

  def post_startup_script
    scripts = ["#!/bin/bash"]
    bb = Dockly::BashBuilder.new
    scripts << bb.normalize_for_dockly
    if get_registry
      scripts << bb.registry_import(docker.repo, docker.tag)
    elsif docker
      if docker.s3_bucket.nil?
        docker_output = File.join(docker.package_dir, docker.export_filename)
        if docker.tar_diff
          scripts << bb.file_diff_docker_import(docker.import, docker_output, docker.name, docker.tag)
        else
          scripts << bb.file_docker_import(docker_output, docker.name, docker.tag)
        end
      else
        if docker.tar_diff
          scripts << bb.s3_diff_docker_import(docker.import, docker.s3_url, docker.name, docker.tag)
        else
          scripts << bb.s3_docker_import(docker.s3_url, docker.name, docker.tag)
        end
      end
      scripts << bb.docker_tag_latest(docker.repo, docker.tag)
    end
    scripts.join("\n")
  end

  def add_startup_script(package)
    ensure_present! :build_dir
    startup_script_path = File.join(build_dir, "dockly-startup.sh")
    File.open(startup_script_path, 'w+') do |f|
      f.write(post_startup_script)
      f.chmod(0755)
    end
    package.attributes[:prefix] = "/opt/dockly"
    Dir.chdir(build_dir) do
      package.input("dockly-startup.sh")
    end
    package.attributes[:prefix] = nil
  end
end
