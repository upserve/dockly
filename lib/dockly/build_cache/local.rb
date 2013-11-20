class Dockly::BuildCache::Local < Dockly::BuildCache::Base
  def run_build
    data = ""
    IO.popen(build_command) do |io|
      data << io.read
    end
    raise "Build Cache `#{build_command}` failed to run." unless $?.success?
    FileUtils.mkdir_p(File.dirname(save_file))
    Dockly::Util::Tar.tar(output_directory, save_file)
  end

  def output_directory
    File.expand_path(File.join(Dir.pwd, output_dir))
  end

  def save_file
    File.expand_path("build/build_cache/#{s3_object_prefix}#{hash_output}")
  end

  def push_cache(version)
    if cache = pull_from_s3(version)
      dest = File.expand_path(output_dir)
      Dockly::Util::Tar.untar(cache, dest)
    else
      info "could not find #{s3_object(output_dir)}"
    end
  end

  def hash_output
    @hash_output ||= begin
      resp = ""
      IO.popen(hash_command) do |io|
        resp << io.read
      end
      raise "Hash Command `#{hash_command} failed to run" unless $?.success?
      resp.strip
    end
  end
end
