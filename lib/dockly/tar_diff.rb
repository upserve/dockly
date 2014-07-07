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
    quick_write(output, size, input)
    skip(input, target_remainder)
    output.write("\0" * remainder)
    self.previous_chunk = input.read
  end

  def quick_write(output, size, target)
    while size > 0
      bread = target.read([size, 4096].min)
      output.write(bread)
      raise UnexpectedEOF if read.eof?
      size -= bread.size
    end
  end

  def read_header(input)
    return if input.eof?

    # Tar header is 512 bytes large
    data = input.read(512)
    fields = data.unpack(HEADER_UNPACK_FORMAT)
    name = fields[0]
    size = fields[4].oct
    mtime = fields[5].oct
    prefix = fields[15]

    empty = (data == "\0" * 512)
    remainder = (512 - (size % 512)) % 512

    return data, name, prefix, mtime, size, remainder, empty
  end

  # Convert from enum style with yield to return style:
  #   - Must be able to allow for less than the size of a full header and full
  #     file from the input
  #   - Operate using StringIO
  def process(raw_input)
    input = StringIO.new(previous_chunk + raw_input)

    unless target_data || input.size > 512
      self.previous_chunk = input.read
      return false
    end

    self.target_data ||= read_header(input)

    target_header, target_name,  \
    target_prefix, target_mtime,  \
    target_size, target_remainder, \
    target_empty                    = target_data

    if target_empty || (input.length - input.pos) > (target_size + target_remainder)
      self.previous_chunk = input.read
      return false
    end

    if base_data || (base.length - base.pos) > 512
      self.base_data ||= read_header(base)

      _, base_name, base_prefix, base_mtime, base_size, _, base_empty = base_data
    else
      write_tar_section(output, target_header, target_size, target_remainder, input)
      return true
    end

    if base_empty
      write_tar_section(output, target_header, target_size, target_remainder, input)
      return true
    end

    target_full_name = File.join(target_prefix, target_name)
    base_full_name = File.join(base_prefix, base_name)

    if (target_full_name < base_full_name)
      write_tar_section(output, target_header, target_size, target_remainder, input)
    elsif (base_full_name < target_full_name)
      skip(base, base_size + base_remainder)
      self.base_data = nil
      self.previous_chunk = input.read
    elsif (target_mtime != base_mtime) || (target_size != base_size)
      write_tar_section(output, target_header, target_size, target_remainder, input)
    else
      skip(input, target_size + target_remainder)
      self.previous_chunk = input.read
      self.target_data = nil
      skip(base, base_size + base_remainder)
      self.base_data = nil
    end

    return true
  end
end
