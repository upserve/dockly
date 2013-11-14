require 'tempfile'

class Dockly::BuildCache
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  logger_prefix '[dockly build_cache]'

  attr_accessor :image
  dsl_attribute :s3_bucket, :s3_object_prefix, :hash_command, :output_dir, :build_command,
                :use_latest, :tmp_dir

  default_value :use_latest, false
  default_value :tmp_dir, '/tmp'

  def execute!
    ensure_present! :image
    debug "Looking for cache for hash: #{hash_output}"
    if up_to_date?
      debug "build cache up to date, pulling from s3"
      insert_cache
    else
      insert_latest
      debug "build cache out of date, running build"
      run_build
    end
    debug "finished build cache"
    image
  end

  def insert_cache
    push_cache(hash_output)
  end

  def insert_latest
    if use_latest
      debug "attempting to push latest"
      if cache = push_cache("latest")
        debug "pushed latest, removing local file"
        File.delete(cache.path)
      end
    end
  end

  def run_build
    container = image.run(build_command)
    status = container.wait(3600)['StatusCode']
    raise "Build Cache `#{build_command}` failed to run." unless status.zero?
    cache = copy_output_dir(container)
    debug "pushing #{output_dir} to s3"
    push_to_s3(cache)
    cache.close
    self.image = container.commit
  end

  def push_cache(version)
    ensure_present! :output_dir
    if cache = pull_from_s3(version)
      debug "inserting to #{output_dir}"
      container = image.run("mkdir #{File.dirname(output_dir)}")
      image_with_dir = container.tap { |c| c.wait }.commit
      self.image = image_with_dir.insert_local(
        'localPath' => cache.path,
        'outputPath' => File.dirname(output_dir)
      )
      cache.close
    else
      info "could not find #{s3_object(version)}"
    end
  end

  def up_to_date?
    ensure_present! :s3_bucket, :s3_object_prefix
    connection.head_object(s3_bucket, s3_object(hash_output))
    true
  rescue Excon::Errors::NotFound
    false
  end

  def pull_from_s3(version)
    ensure_present! :s3_bucket, :s3_object_prefix

    file_name = s3_object(version)
    file_path = File.join(tmp_dir,file_name)

    FileUtils.mkdir_p(File.dirname(file_path))
    unless File.exist?(file_path)
      object = connection.get_object(s3_bucket, file_name)

      file = File.open(file_path, 'w+b')
      file.write(object.body)
      file.tap(&:rewind)
    else
      File.open(file_path, 'rb')
    end
  rescue Excon::Errors::NotFound
    nil
  end

  def push_to_s3(file)
    ensure_present! :s3_bucket, :s3_object_prefix
    connection.put_object(s3_bucket, s3_object(hash_output), file.read)
    connection.copy_object(s3_bucket, s3_object(hash_output), s3_bucket, s3_object("latest"))
  end

  def copy_output_dir(container)
    ensure_present! :output_dir
    file_path = File.join(tmp_dir,s3_object(hash_output))
    FileUtils.mkdir_p(File.dirname(file_path))
    file = File.open(file_path, 'w+b')
    container.wait(3600) # 1 hour max timeout
    container.copy(output_dir) { |chunk| file.write(chunk) }
    file.tap(&:rewind)
  end

  def hash_output
    ensure_present! :image, :hash_command
    @hash_output ||= begin
      resp = ""
      container = image.run(hash_command)
      container.attach { |chunk| resp += chunk }
      status = container.wait['StatusCode']
      raise "Hash Command `#{hash_command} failed to run" unless status.zero?
      resp.strip
    end
  end

  def file_output(file)
    File.join(File.dirname(output_dir), File.basename(file.path))
  end

  def s3_object(file)
    "#{s3_object_prefix}#{file}"
  end

  def connection
    Dockly::AWS.s3
  end
end
