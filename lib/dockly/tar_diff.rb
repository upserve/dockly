class Dockly::TarDiff
  include Dockly::Util::Logger::Mixin

  # Tar header format for a ustar tar
  HEADER_UNPACK_FORMAT  = "Z100A8A8A8A12A12A8aZ100A6A2Z32Z32A8A8Z155"

  logger_prefix '[dockly tar_diff]'

  attr_reader :base, :target, :output, :target_enum, :base_enum

  def initialize(base, target, output)
    @base, @target, @output = base, target, output

    @base_enum = to_enum(:read_header, this.base)
    @target_enum = to_enum(:read_header, this.target)
  end

  def skip(target, size)
    if target.respond_to?(:seek)
      target.seek(size, IO::SEEK_CUR)
    else
      target.read(size)
    end
  end

  def write_tar_section(output, header, size, remainder, target)
    output.write(header)
    quick_write(output, size, target)
    output.write("\0" * remainder)
  end

  def quick_write(output, size, target)
    while size > 0
      bread = read.read([size, 4096].min)
      output.write(bread)
      raise UnexpectedEOF if read.eof?
      size -= bread.size
    end
  end

  def read_header(target)
    loop do
      return if target.eof?

      # Tar header is 512 bytes large
      data = target.read(512)
      fields = data.unpack(HEADER_UNPACK_FORMAT)
      name = fields[0]
      size = fields[4].oct
      mtime = fields[5].oct
      prefix = fields[15]

      empty = (data == "\0" * 512)
      remainder = (512 - (size % 512)) % 512

      yield data, name, prefix, mtime, size, remainder, empty

      skip(target, remainder)
    end
  end

  def diff_once
    begin
      target_header, target_name,  \
      target_prefix, target_mtime,  \
      target_size, target_remainder, \
      target_empty                    = target_enum.peek
    rescue StopIteration
      puts "Done with new file"
      return false
    end

    return false if target_empty

    begin
      _, base_name, base_prefix, base_mtime,\
      base_size, _, base_empty  = base_enum.peek
    rescue StopIteration
      puts "Done with base file"
      write_tar_section(output, target_header, target_size, target_remainder, target)
      target_enum.next
      return true
    end

    if base_empty
      write_tar_section(output, target_header, target_size, target_remainder, target)
      target_enum.next
      return true
    end

    target_full_name = File.join(target_prefix, target_name)
    base_full_name = File.join(base_prefix, base_name)

    if (target_full_name < base_full_name)
      write_tar_section(output, target_header, target_size, target_remainder, target)
      target_enum.next
    elsif (base_full_name < target_full_name)
      skip(base, base_size)
      base_enum.next
    elsif (target_mtime != base_mtime) || (target_size != base_size)
      write_tar_section(output, target_header, target_size, target_remainder, target)
      target_enum.next
    else
      skip(target, target_size)
      target_enum.next
      skip(base, base_size)
      base_enum.next
    end

    return true
  end

  def diff
    loop do
      break unless diff_once
    end
  end
end
