module Dockly
  class S3Writer
    include Dockly::Util::Logger::Mixin
    extend Forwardable

    MAX_BUFFER_SIZE = 5 * 1024 * 1024

    attr_reader :connection, :s3_bucket, :s3_object, :parts, :closed, :buffer

    def_delegators :multipart_upload, :upload_id
    logger_prefix '[dockly s3writer]'

    def initialize(connection, s3_bucket, s3_object)
      @connection = connection
      @s3_bucket = s3_bucket
      @s3_object = s3_object
      @parts = []
      @closed = false
      @buffer = StringIO.new
    end

    def upload_buffer
      num = @parts.length.succ
      debug "Writing a chunk ##{num} to s3://#{s3_bucket}/#{s3_object} with upload id #{upload_id}"
      res = connection.upload_part(
        bucket: s3_bucket,
        key: s3_object,
        upload_id: upload_id,
        part_number:num,
        body: buffer
      )
      @parts << res.etag
      @buffer = StringIO.new
    end

    def write(chunk)
      @buffer.write(chunk)
      upload_buffer if buffer.size > MAX_BUFFER_SIZE
      chunk.length
    end

    def close
      return if @closed
      upload_buffer unless buffer.size.zero?
      connection.complete_multipart_upload(
        bucket: s3_bucket,
        key: s3_object,
        upload_id: upload_id,
        parts: @parts.each_with_index.map do |part, idx|
          {
            etag: part,
            part_number: idx.succ
          }
        end
      )
      @closed = true
    end

    def abort_upload
      connection.abort_multipart_upload(
        bucket: s3_bucket,
        key: s3_object,
        upload_id: upload_id
      )
    end

    def abort_unless_closed
      abort_upload unless @closed
      @closed = true
    end

    def multipart_upload
      @multipart_upload ||=
        connection.create_multipart_upload(bucket: s3_bucket, key: s3_object)
    end
  end
end
