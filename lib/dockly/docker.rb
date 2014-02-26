require 'docker'
require 'excon'
require 'tempfile'
require 'zlib'
require 'rubygems/package'
require 'fileutils'

class Dockly::Docker
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  autoload :Registry, 'dockly/docker/registry'

  logger_prefix '[dockly docker]'

  dsl_class_attribute :build_cache, Dockly::BuildCache.model, type: Array
  dsl_class_attribute :registry, Dockly::Docker::Registry

  dsl_attribute :name, :import, :git_archive, :build, :tag, :build_dir, :package_dir,
    :timeout, :cleanup_images, :auth_config_file

  default_value :tag, nil
  default_value :build_dir, 'build/docker'
  default_value :package_dir, '/opt/docker'
  default_value :cleanup_images, false
  default_value :timeout, 60

  def generate!
    Docker.options = { :read_timeout => timeout, :write_timeout => timeout }
    images = {}

    if registry_import.nil?
      docker_tar = File.absolute_path(ensure_tar(fetch_import))
      images[:one] = import_base(docker_tar)
    else
      registry.authenticate! unless registry.nil?
      full_name = "#{registry_import[:name]}:#{registry_import[:tag]}"
      info "Pulling #{full_name}"
      images[:one] = ::Docker::Image.create('repo' => registry_import[:name], 'tag' => registry_import[:tag])
      info "Successfully pulled #{full_name}"
    end

    images[:two] = add_git_archive(images[:one])
    images[:three] = run_build_caches(images[:two])
    images[:four] = build_image(images[:three])

    export_image(images[:four])

    true
  ensure
    cleanup(images.values.compact) if cleanup_images
  end

  def registry_import(img_name = nil, opts = {})
    if img_name
      @registry_import ||= {}
      @registry_import[:name] = img_name
      @registry_import[:tag] = opts[:tag] || 'latest'
    else
      @registry_import
    end
  end

  def cleanup(images)
    ::Docker::Container.all(:all => true).each do |container|
      image_id = container.json['Image']
      if images.any? { |image| image.id.start_with?(image_id) || image_id.start_with?(image.id) }
        container.kill
        container.delete
      end
    end
    images.each { |image| image.remove rescue nil }
  end

  def export_filename
    "#{name}-image.tgz"
  end

  def run_build_caches(image)
    info "starting build caches"
    (build_cache || []).each do |cache|
      cache.image = image
      image = cache.execute!
    end
    info "finished build caches"
    image
  end

  def tar_path
    File.join(build_dir, export_filename)
  end

  def ensure_tar(file_name)
    if Dockly::Util::Tar.is_tar?(file_name)
      file_name
    elsif Dockly::Util::Tar.is_gzip?(file_name)
      file_name
    else
      raise "Expected a (possibly gzipped) tar: #{file_name}"
    end
  end

  def make_git_archive
    ensure_present! :git_archive
    info "initializing"

    prefix = git_archive
    prefix += '/' unless prefix.end_with?('/')

    FileUtils.rm_rf(git_archive_dir)
    FileUtils.mkdir_p(git_archive_dir)
    info "archiving #{Dockly::Util::Git.git_sha}"
    Grit::Git.with_timeout(120) do
      Dockly::Util::Git.git_repo.archive_to_file(Dockly::Util::Git.git_sha, prefix, git_archive_path, 'tar', 'cat')
    end
    git_archive_path
  end

  def git_archive_dir
    @git_archive_dir ||= File.join(build_dir, "gitarc")
  end

  def git_archive_path
    "#{git_archive_dir}/#{name}.tar"
  end

  def git_archive_tar
    git_archive && File.absolute_path(make_git_archive)
  end

  def import_base(docker_tar)
    info "importing the docker image from #{docker_tar}"
    image = ::Docker::Image.import(docker_tar)
    info "imported docker image: #{image.id}"
    image
  end

  def add_git_archive(image)
    return image if git_archive.nil?

    image.insert_local(
      'localPath' => git_archive_tar,
      'outputPath' => '/'
    )
  end

  def build_image(image)
    ensure_present! :name, :build
    info "starting build from #{image.id}"
    out_image = ::Docker::Image.build("from #{image.id}\n#{build}")
    info "built the image: #{out_image.id}"
    out_image.tag(:repo => repo, :tag => tag)
    out_image
  end

  def repo
    @repo ||= case
    when registry.nil?
      name
    when registry.default_server_address?
      "#{registry.username}/#{name}"
    else
      "#{registry.server_address}/#{name}"
    end
  end

  def export_image(image)
    ensure_present! :name
    if registry.nil?
      ensure_present! :build_dir
      container = ::Docker::Container.create('Image' => image.id, 'Cmd' => %w[true])
      info "created the container: #{container.id}"
      Zlib::GzipWriter.open(tar_path) do |file|
        container.export do |chunk, remaining, total|
          file.write(chunk)
        end
      end
      info "done writing the docker tar: #{export_filename}"
    else
      push_to_registry(image)
    end
  end

  def push_to_registry(image)
    ensure_present! :registry
    info "Exporting #{image.id} to Docker registry at #{registry.server_address}"
    registry.authenticate!
    image = Docker::Image.all(:all => true).find { |img|
      img.id.start_with?(image.id) || image.id.start_with?(img.id)
    }
    raise "Could not find image after authentication" if image.nil?
    image.push(registry.to_h, :registry => registry.server_address)
  end

  def fetch_import
    ensure_present! :import
    path = "/tmp/dockly-docker-import.#{name}.#{File.basename(import)}"

    if File.exist?(path)
      debug "already fetched #{import}"
    else
      debug "fetching #{import}"
      File.open("#{path}.tmp", 'wb') do |file|
        case import
          when /^s3:\/\/(?<bucket_name>.+?)\/(?<object_path>.+)$/
            connection.get_object(Regexp.last_match[:bucket_name],
                                  Regexp.last_match[:object_path]) do |chunk, remaining, total|
              file.write(chunk)
            end
          when /^https?:\/\//
            Excon.get(import, :response_block => lambda { |chunk, remaining, total|
              file.write(chunk)
            })
          else
            raise "You can only import from S3 or a public url"
        end
      end
      FileUtils.mv("#{path}.tmp", path, :force => true)
    end
    path
  end

  def repository(value = nil)
    name(value)
  end

private
  def connection
    Dockly::AWS.s3
  end
end
