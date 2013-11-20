require 'rubygems'
require 'rubygems/package'
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
    tarfile = File.open(output, 'wb')
    Gem::Package::TarWriter.new(tarfile) do |tar|
      Dir[File.join(path, "**/*")].each do |file|
        mode = File.stat(file).mode
        relative_file = file.sub(/^#{Regexp::escape path}\/?/, '')

        if File.directory?(file)
          tar.mkdir relative_file, mode
        else
          tar.add_file relative_file, mode do |tf|
            begin
              File.open(file, "rb") { |f| tf.write f.read }
            rescue => ex
              binding.pry
            end
          end
        end
      end
    end

    tarfile.rewind
    tarfile
  end

  # untars the given IO into the specified
  # directory
  def untar(io, destination)
    Gem::Package::TarReader.new io do |tar|
      tar.each do |tarfile|
        destination_file = File.join destination, tarfile.full_name

        if tarfile.directory?
          FileUtils.mkdir_p destination_file
        else
          destination_directory = File.dirname(destination_file)
          FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
          File.open destination_file, "wb" do |f|
            f.print tarfile.read
          end
        end
      end
    end
  end
end
