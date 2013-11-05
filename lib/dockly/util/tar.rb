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
end
