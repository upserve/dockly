require 'spec_helper'

describe Dockly::AWS::S3Writer do
  let(:connection) { double(:connection) }
  let(:bucket) { 'test_bucket' }
  let(:object) { 'object_name.tar' }
  let(:initiate_response) { double(:initiate_response) }
  let(:upload_id) { 'test_id' }

  subject { described_class.new(connection, bucket, object) }

  before do
    connection.should_receive(:initiate_multipart_upload) { initiate_response }
    initiate_response.stub(:body) { { 'UploadId' => upload_id } }
  end

  describe ".new" do

    it "sets the connection, s3_bucket, s3_object, and upload_id" do
      expect(subject.connection).to eq(connection)
      expect(subject.s3_bucket).to eq(bucket)
      expect(subject.s3_object).to eq(object)
      expect(subject.upload_id).to eq(upload_id)
    end
  end

  describe "#upload_buffer" do
    let(:message) { "message" }
    let(:upload_response) { double(:upload_response) }
    let(:etag) { "test" }

    before do
      connection.should_receive(:upload_part).with(bucket, object, upload_id, 1, message) do
        upload_response
      end
      upload_response.stub(:headers) { { "ETag" => etag } }
      subject.instance_variable_set(:"@buffer", message)
    end

    it "connects to S3" do
      subject.upload_buffer
      expect(subject.instance_variable_get(:"@parts")).to include(etag)
    end
  end

  describe "#write" do
    let(:message) { "a" * chunk_length }

    context "with a buffer of less than 5 MB" do
      let(:chunk_length) { 100 }
      
      before do
        subject.should_not_receive(:upload_buffer)
      end

      it "adds it to the buffer and returns the chunk length" do
        expect(subject.write(message)).to eq(chunk_length)
        expect(subject.instance_variable_get(:"@buffer")).to eq(message)
      end
    end

    context "with a buffer of greater than 5 MB"  do
      let(:chunk_length) { 1 + 5 * 1024 * 1024 }

      before do
        subject.should_receive(:upload_buffer)
      end

      it "adds it to the buffer, writes to S3 and returns the chunk length" do
        expect(subject.write(message)).to eq(chunk_length)
      end
    end
  end

  describe "#close" do
    let(:complete_response) { double(:complete_response) }

    before do
      connection.should_receive(:complete_multipart_upload).with(bucket, object, upload_id, []) do
        complete_response
      end
    end

    context "when it passes" do
      before do
        complete_response.stub(:body) { {} }
      end

      context "when the buffer is not empty" do
        before do
          subject.instance_variable_set(:"@buffer", "text")
          subject.should_receive(:upload_buffer)
        end

        it "uploads the rest of the buffer and closes the connection" do
          expect(subject.close).to be_true
        end
      end

      context "when the buffer is empty" do
        before do
          subject.should_not_receive(:upload_buffer)
        end

        it "closes the connection" do
          expect(subject.close).to be_true
        end
      end
    end

    context "when it fails" do
      before do
        complete_response.stub(:body) { { 'Code' => 20, 'Message' => 'Msggg' } }
      end

      it "raises an error" do
        expect { subject.close }.to raise_error("Failed to upload to S3: 20: Msggg")
      end
    end
  end

  describe "#abort" do
    before do
      connection.should_receive(:abort_multipart_upload).with(bucket, object, upload_id)
    end

    it "aborts the upload" do
      subject.abort
    end
  end

  describe "#abort_unless_closed" do
    context "when the upload is closed" do
      before do
        subject.should_not_receive(:abort)
        subject.instance_variable_set(:"@closed", true)
      end

      it "does not abort" do
        subject.abort_unless_closed
      end
    end

    context "when the upload is open" do
      before do
        subject.should_receive(:abort)
      end
      
      it "aborts the upload" do
        subject.abort_unless_closed
      end
    end
  end
end
