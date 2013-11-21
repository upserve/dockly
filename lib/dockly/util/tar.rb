require 'fileutils'

module Dockly::Util::Tar
  extend self

  def is_tar?(path)
    if File.size(path) < 262
      return false
    end
    magic = nil
    File.open(path, "r") do |f|
      f.read(257)
      magic = f.read(5)
    end
    magic == "ustar"
  end

  def is_gzip?(path)
    if File.size(path) < 2
      return false
    end
    magic = nil
    File.open(path, "r") do |f|
      magic = f.read(2)
    end
    magic = magic.unpack('H*')[0]
    magic == "1f8b"
  end

  # Creates a tar file in memory recursively
  # from the given path.
  #
  # Returns a StringIO whose underlying String
  # is the contents of the tar file.
  def tar(path, output)
    FileUtils.mkdir_p(File.dirname(output))
    puts "tarring #{path} to #{output}"
    tar_command = "tar -cf #{output} -C #{File.dirname(path)} #{File.basename(path)}"
    puts "Tar Command: #{tar_command}"
    IO.popen(tar_command) do |io|
      puts io.read
    end
    File.open(output, 'rb+')
  end

  # untars the given IO into the specified
  # directory
  def untar(input_io, destination)
    puts "untarring #{input_io.path} to #{destination}"
    FileUtils.mkdir_p(destination)
    untar_command = "tar -xf #{input_io.path} -C #{destination}"
    puts "Untar command: #{untar_command}"
    IO.popen(untar_command) do |io|
      puts io.read
    end
    input_io
  end
end
