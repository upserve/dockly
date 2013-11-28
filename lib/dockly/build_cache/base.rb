require 'tempfile'

class Dockly::BuildCache::Base
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  logger_prefix '[dockly build_cache]'

  dsl_attribute :s3_bucket, :s3_object_prefix, :use_latest,
                :hash_command, :build_command, :parameter_commands,
                :base_dir, :command_dir, :output_dir, :tmp_dir

  default_value :use_latest, false
  default_value :parameter_commands, {}
  default_value :command_dir, '.'
  default_value :output_dir, '.'
  default_value :tmp_dir, '/tmp'

  def execute!
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

  def hash_output
  end

  def parameter_output(command)
  end

  def parameter_command(command)
    parameter_commands[command] = nil
  end

  def push_to_s3(file)
    ensure_present! :s3_bucket, :s3_object_prefix
    connection.put_object(s3_bucket, s3_object(hash_output), file.read)
    connection.copy_object(s3_bucket, s3_object(hash_output), s3_bucket, s3_object("latest"))
  end

  def file_output(file)
    File.join(File.dirname(output_dir), File.basename(file.path))
  end

  def s3_object(file)
    output = "#{s3_object_prefix}"
    parameter_commands.each do |parameter_command, _|
      output << "#{parameter_output(parameter_command)}_" unless parameter_output(parameter_command).nil?
    end
    output << "#{file}"
  end

  def command_directory
    File.join(base_directory, command_dir)
  end

  def output_directory
    File.join(base_directory, output_dir)
  end

  def base_directory
    base_dir || docker.git_archive
  end

  def connection
    Dockly::AWS.s3
  end
end
