module Dockly
  module AWS
    class S3Writer
      include Dockly::Util::Logger::Mixin

      logger_prefix '[dockly s3writer]'

      attr_accessor :buffer
      attr_reader :connection, :s3_bucket, :s3_object, :upload_id

      def initialize(connection, s3_bucket, s3_object)
        @connection = connection
        @s3_bucket = s3_bucket
        @s3_object = s3_object
        @parts = []
        @closed = false
        @buffer = ""

        init_upload_res = connection.initiate_multipart_upload(s3_bucket, s3_object)
        @upload_id = init_upload_res.body['UploadId']
      end

      def write(chunk)
        self.buffer << chunk

        if buffer.bytesize > 5242880
          res = connection.upload_part(s3_bucket, s3_object, upload_id, @parts.size + 1, buffer)
          @parts << res.headers["ETag"]
          debug "Writing a chunk"
          @buffer = ""
        end

        chunk.length
      end

      def close
        res = connection.complete_multipart_upload(s3_bucket, s3_object, upload_id, @parts)
        if res.body['Code'] || res.body['Message']
          raise "Failed to upload to S3: #{res.body['Code']}: #{res.body['Message']}"
        end
        @closed = true
      end

      def abort
        connection.abort_multipart_upload(s3_bucket, s3_object, upload_id)
      end

      def abort_unless_closed
        abort unless @closed
      end
    end
  end
end
