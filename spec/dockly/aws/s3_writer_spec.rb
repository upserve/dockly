require 'spec_helper'

describe Dockly::AWS::S3Writer do
  let(:connection) { double(:connection) }
  let(:bucket) { 'test_bucket' }
  let(:object) { 'object_name.tar' }
  let(:multipart_upload) { double(:multipart_upload, upload_id: upload_id) }
  let(:upload_id) { 'test_id' }

  before do
    allow(subject)
      .to receive(:multipart_upload)
      .and_return(multipart_upload)
  end

  subject { described_class.new(connection, bucket, object) }

  describe '.new' do
    it 'sets the connection, s3_bucket, s3_object, and upload_id' do
      expect(subject.connection).to eq(connection)
      expect(subject.s3_bucket).to eq(bucket)
      expect(subject.s3_object).to eq(object)
    end
  end

  describe '#upload_id' do
    it 'delegates to the multipart_upload' do
      expect(subject.upload_id).to eq(multipart_upload.upload_id)
    end
  end

  describe '#upload_buffer' do
    let(:input) { 'Some String' }
    let(:io) { StringIO.new(input) }
    let(:upload_response) { double(:upload_response, etag: etag) }
    let(:etag) { 'test' }

    before do
      subject.instance_variable_set(:@buffer, io)

      allow(connection)
        .to receive(:upload_part)
        .with(bucket: bucket, key: object, upload_id: upload_id, part: 1, body: io)
        .and_return(upload_response)
    end

    it 'uploads to S3' do
      expect { subject.upload_buffer }
        .to change { subject.parts.last }
        .to(etag)
    end

    it 'clears the buffer' do
      expect { subject.upload_buffer }
        .to change { subject.buffer.tap(&:rewind).string }
        .from(input)
        .to('')
    end
  end

  describe '#write' do
    let(:message) { 'a' * chunk_length }

    context 'with a buffer of less than 5 MB' do
      let(:chunk_length) { 100 }

      it 'adds it to the buffer and returns the chunk length' do
        expect(subject).to_not receive(:upload_buffer)
        expect(subject.write(message)).to eq(chunk_length)
        expect(subject.buffer.tap(&:rewind).string).to eq(message)
      end
    end

    context 'with a buffer of greater than 5 MB'  do
      let(:chunk_length) { 1 + 5 * 1024 * 1024 }

      it 'adds it to the buffer, writes to S3 and returns the chunk length' do
        expect(subject).to receive(:upload_buffer)
        expect(subject.write(message)).to eq(chunk_length)
      end
    end
  end

  describe '#close' do
    let(:complete_response) { double(:complete_response) }

    before do
      allow(connection)
        .to receive(:complete_multipart_upload)
        .with(bucket: bucket, key: object, upload_id: upload_id, parts: [])
        .and_return(complete_response)
    end

    context 'when it passes' do
      context 'when the buffer is not empty' do
        before { subject.instance_variable_set(:@buffer, StringIO.new('text')) }

        it 'uploads the rest of the buffer and closes the connection' do
          expect(subject).to receive(:upload_buffer)
          expect(subject.close).to be_true
        end
      end

      context 'when the buffer is empty' do
        it 'closes the connection' do
          expect(subject).to_not receive(:upload_buffer)
          expect(subject.close).to be_true
        end
      end
    end
  end

  describe '#abort_upload' do
    it 'aborts the upload' do
      expect(connection)
        .to receive(:abort_multipart_upload)
        .with(bucket: bucket, key: object, upload_id: upload_id)
      subject.abort_upload
    end
  end

  describe '#abort_unless_closed' do
    context 'when the upload is closed' do
      before { subject.instance_variable_set(:@closed, true) }

      it 'does not abort' do
        expect(subject).to_not receive(:abort_upload)
        subject.abort_unless_closed
      end
    end

    context 'when the upload is open' do
      it 'aborts the upload' do
        expect(subject).to receive(:abort_upload)
        subject.abort_unless_closed
      end
    end
  end
end
