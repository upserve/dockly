class Dockly::BuildCache::Local < Dockly::BuildCache::Base
  def run_build
    puts "Build command: #{build_command}"
    status, body = run_command(build_command)
    raise "Build Cache `#{build_command}` failed to run." unless status.success?
    FileUtils.mkdir_p(File.dirname(save_file))
    tar_file = Dockly::Util::Tar.tar(output_directory, save_file)
    push_to_s3(tar_file)
  end

  def output_directory
    File.expand_path(File.join(Dir.pwd, output_dir))
  end

  def save_file
    File.expand_path("build/build_cache/#{s3_object_prefix}#{hash_output}")
  end

  def push_cache(version)
    ensure_present! :output_dir
    if cache = pull_from_s3(version)
      dest = File.dirname(File.expand_path(output_dir))
      Dockly::Util::Tar.untar(cache, dest)
    else
      info "could not find #{s3_object(output_dir)}"
    end
  end

  def hash_output
    ensure_present! :hash_command
    @hash_output ||= begin
      status, body = run_command(hash_command)
      raise "Hash Command `#{hash_command} failed to run" unless status.success?
      body
    end
  end

  def parameter_output(command)
    raise "Parameter Command tried to run but not found" unless parameter_commands.keys.include?(command)
    @parameter_commands[command] ||= begin
      status, body = run_command(command)
      raise "Parameter Command `#{command} failed to run" unless status.success?
      body
    end
  end

  def run_command(command)
    resp = ""
    run_with_bundler do
      IO.popen(command) do |io|
        resp << io.read
      end
    end
    [$?, resp.strip]
  end

  if defined?(Bundler)
    def run_with_bundler
      Bundler.with_clean_env do
        yield
      end
    end
  else
    def run_with_bundler
      yield
    end
  end
end
