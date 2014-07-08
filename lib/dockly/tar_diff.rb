class Dockly::TarDiff
  include Dockly::Util::Logger::Mixin

  # Tar header format for a ustar tar
  HEADER_UNPACK_FORMAT  = "Z100A8A8A8A12A12A8aZ100A6A2Z32Z32A8A8Z155"

  logger_prefix '[dockly tar_diff]'

  attr_reader :base, :output, :base_enum, :base_data, :target_data

  attr_accessor :base_data, :target_data, :previous_chunk

  def initialize(base, output)
    @previous_chunk = ""
    @base, @output, @input = base, output, StringIO.new

    @base_data = @target_data = nil
  end

  def skip(io, size)
    if io.respond_to?(:seek)
      io.seek(size, IO::SEEK_CUR)
    else
      io.read(size)
    end
  end

  def write_tar_section(output, header, size, remainder, input)
    self.target_data = nil
    output.write(header)
    output.write(input.slice!(0, size + remainder))
    self.previous_chunk = input
  end

  def quick_write(output, target)
    size = target.size
    while size > 0
      bread = target.slice!(0, [size, 4096].min)
      output.write(bread)
      size -= bread.size
    end
  end

  def read_header(data)
    # Tar header is 512 bytes large
    fields = data.unpack(HEADER_UNPACK_FORMAT)
    name = fields[0]
    size = fields[4].oct
    mtime = fields[5].oct
    prefix = fields[15]

    empty = (data == "\0" * 512)
    remainder = (512 - (size % 512)) % 512

    return data, name, prefix, mtime, size, remainder, empty
  end

  def set_chunk(raw_input)
    self.previous_chunk = previous_chunk + raw_input
  end

  def process
    input = previous_chunk.dup

    if target_data || input.size >= 512
      self.target_data ||= read_header(input.slice!(0, 512))

      target_header, target_name,  \
      target_prefix, target_mtime,  \
      target_size, target_remainder, \
      target_empty                    = target_data
    else
      #puts "Size is too small"
      self.previous_chunk = input
      return false
    end

    if target_empty || input.size < (target_size + target_remainder)
      self.previous_chunk = input
      return false
    end

    if base_data || (base.size - base.pos) >= 512
      self.base_data ||= read_header(base.read(512))

      _, base_name, base_prefix, base_mtime, base_size, base_remainder, base_empty = base_data
    else
      #puts "Base is empty"
      write_tar_section(output, target_header, target_size, target_remainder, input)
      return true
    end

    if base_empty
      #puts "Base is actually empty"
      write_tar_section(output, target_header, target_size, target_remainder, input)
      return true
    end

    target_full_name = File.join(target_prefix, target_name)
    base_full_name = File.join(base_prefix, base_name)

    target_full_name = target_full_name[1..-1] if target_full_name[0] == '/'
    base_full_name = base_full_name[1..-1] if base_full_name[0] == '/'

    if (target_full_name < base_full_name)
      write_tar_section(output, target_header, target_size, target_remainder, input)
    elsif (base_full_name < target_full_name)
      skip(base, base_size + base_remainder)
      self.previous_chunk = input
      self.base_data = nil
    elsif (target_mtime != base_mtime) || (target_size != base_size)
      write_tar_section(output, target_header, target_size, target_remainder, input)
    else
      input.slice!(0, target_size + target_remainder)
      self.previous_chunk = input
      self.target_data = nil
      skip(base, base_size + base_remainder)
      self.base_data = nil
    end

    return true
  end
end
