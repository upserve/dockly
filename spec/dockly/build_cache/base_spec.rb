require 'spec_helper'

describe Dockly::BuildCache::Base do
  subject { described_class.new(:name => :test_build_cache) }

  before do
    subject.s3_bucket 'lol'
    subject.s3_object_prefix 'swag'
    subject.hash_command 'md5sum /etc/vim/vimrc'
    subject.build_command 'touch lol'
    subject.output_dir '/'
  end

  describe '#up_to_date?' do
    context 'when the object exists in s3' do
      before do
        allow(Dockly)
          .to receive(:s3)
          .and_return(
            Aws::S3::Client.new(stub_responses: true)
          )
      end

      its(:up_to_date?) { should be_true }
    end

    context 'when the object does not exist in s3' do
      before do
        allow(Dockly)
          .to receive(:s3)
          .and_return(
            Aws::S3::Client.new(
              stub_responses: { :head_object => 'NoSuchKey' }
            )
          )
      end

      its(:up_to_date?) { should be_false }
    end
  end

  describe '#pull_from_s3' do
    let(:file) { subject.pull_from_s3('hey') }
    let(:object) { double(:object) }

    before do
      allow(Dockly)
        .to receive(:s3)
        .and_return(Aws::S3::Client.new(
          stub_responses: { :get_object => object }
        ))

      allow(object)
        .to receive(:body)
        .and_return(StringIO.new('hey dad').tap(&:rewind))
    end

    after do
      path = file.path
      file.close
      File.delete(path)
    end

    it 'returns a File with the data pulled' do
      file.read.should == 'hey dad'
    end
  end

  describe '#s3_object' do
    before do
      allow(subject).to receive(:s3_object_prefix).and_return('lol')
      allow(subject).to receive(:hash_output).and_return('lel')
    end

    context "without an arch_output" do
      it 'returns the s3_prefix merged with the hash_output' do
        subject.s3_object(subject.hash_output).should == 'lollel'
      end
    end

    context "with an arch_output" do
      before do
        subject.parameter_command "linux"
        subject.stub(:parameter_output) { "linux" }
      end

      it 'returns the s3_prefix merged with the hash_output' do
        subject.s3_object(subject.hash_output).should == 'lollinux_lel'
      end
    end
  end
end
