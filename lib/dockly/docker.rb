require 'docker'
require 'excon'
require 'tempfile'
require 'zlib'
require 'rubygems/package'
require 'fileutils'

class Dockly::Docker
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  logger_prefix '[dockly docker]'
  dsl_attribute :name, :import, :git_archive, :build, :tag, :build_dir, :package_dir,
    :timeout, :cleanup_images, :build_caches

  default_value :tag, nil
  default_value :build_dir, 'build/docker'
  default_value :package_dir, '/opt/docker'
  default_value :build_caches, []
  default_value :cleanup_images, false
  default_value :timeout, 60

  def generate!
    Docker.options = { :read_timeout => timeout, :write_timeout => timeout }
    docker_tar = File.absolute_path(ensure_tar(fetch_import))

    import = import_base(docker_tar)

    cleanup = add_git_archive(import)
    cleanup = run_build_caches(cleanup)
    cleanup = build_image(cleanup)

    export_image(cleanup)

    true
  ensure
    cleanup.remove if cleanup_images && !cleanup.nil?
  end

  def export_filename
    "#{name}-image.tgz"
  end

  def run_build_caches(image)
    info "starting build caches"
    build_caches.each do |cache|
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
    out_image.tag(:repo => name, :tag => tag)
    out_image
  end

  def export_image(image)
    ensure_present! :name, :build_dir
    container = ::Docker::Container.create('Image' => image.id, 'Cmd' => %w[true])
    info "created the container: #{container.id}"
    Zlib::GzipWriter.open(tar_path) do |file|
      container.export do |chunk, remaining, total|
        file.write(chunk)
      end
    end
    info "done writing the docker tar: #{export_filename}"
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

  def build_cache(&block)
    build_caches << Dockly::BuildCache.new(&block)
  end

  def repository(value = nil)
    name(value)
  end

private
  def connection
    Dockly::AWS.s3
  end
end
