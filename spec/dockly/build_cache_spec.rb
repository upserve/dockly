require 'spec_helper'

describe Dockly::BuildCache, :docker do
  subject { described_class.new(:name => :test_build_cache) }
  let(:image) { ::Docker::Image.build('from base') }

  before do
    subject.s3_bucket 'lol'
    subject.s3_object_prefix 'swag'
    subject.image = image
    subject.hash_command 'md5sum /etc/vim/vimrc'
    subject.build_command 'touch lol'
    subject.output_dir '/'
  end

  describe '#execute!' do
    before do
      subject.stub(:up_to_date?).and_return(up_to_date)
      subject.stub(:push_cache)
      subject.stub(:push_to_s3)
    end

    context 'when the object is up to date' do
      let(:up_to_date) { true }

      it "does not have the file lol" do
        i = subject.execute!
        output = ""
        i.run('ls').attach { |source,chunk| output += chunk }
        output.should_not include('lol')
      end
    end

    context 'when the object is not up to date' do
      let(:up_to_date) { false }

      it "does have the file lol" do
        i = subject.execute!
        output = ""
        i.run('ls').attach { |source,chunk| output += chunk }
        output.should include('lol')
      end
    end
  end

  describe "#run_build" do
    before do
      subject.stub(:push_to_s3)
    end

    context "when the build succeeds" do
      it "does have the file lol" do
        i = subject.run_build
        output = ""
        i.run('ls').attach { |source,chunk| output += chunk }
        output.should include('lol')
      end
    end

    context "when the build fails" do
      let!(:image) { subject.image }
      before do
        subject.image = double(:image).stub(:run) {
          stub(:container, { :wait => { 'StatusCode' => 1 } })
        }
      end

      after do
        subject.image = image
      end

      it "raises an error" do
        expect { subject.run_build }.to raise_error
      end
    end
  end

  describe '#pull_from_s3' do
    let(:file) { subject.pull_from_s3('hey') }
    let(:object) { double(:object) }

    before do
      subject.connection.stub(:get_object).and_return object
      object.stub(:body).and_return 'hey dad'
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

  describe '#up_to_date?' do
    context 'when the object exists in s3' do
      before { subject.connection.stub(:head_object) }

      its(:up_to_date?) { should be_true }
    end

    context 'when the object does not exist in s3' do
      before do
        subject.connection.stub(:head_object)
            .and_raise(Excon::Errors::NotFound.new('help'))
      end

      its(:up_to_date?) { should be_false }
    end
  end

  describe '#hash_output' do
    let(:output) {
      "682aa2a07693cc27756eee9751db3903  /etc/vim/vimrc"
    }

    context "when hash command returns successfully" do
      before do
        subject.image = image
      end

      it 'returns the output of the hash_command in the container' do
        subject.hash_output.should == output
      end
    end

    context "when hash command returns failure" do
      before do
        subject.image = double(:image).stub(:run, {
          :wait => { 'StatusCode' => 1 }
        })
      end

      it 'raises an error' do
        expect { subject.hash_output }.to raise_error
      end
    end
  end

  describe '#copy_output_dir' do
    let(:container) { Docker::Container.create('Image' => 'base', 'Cmd' => %w[true]) }
    let(:file) { subject.copy_output_dir(container) }
    let(:hash) { 'this_really_unique_hash' }
    let(:path) { file.path }

    before do
      subject.stub(:hash_output).and_return(hash)
      subject.output_dir '/root/'; container.wait
    end
    after do
      file.close
      File.delete(path)
    end

    it 'returns a File of the specified directory from the Container' do
      expect(file.path).to include("#{hash}")
      file.should be_a File
      file.read.should include('root/.bashrc')
    end
  end

  describe '#s3_object' do
    before do
      subject.stub(:s3_object_prefix) { 'lol' }
      subject.stub(:hash_output) { 'lel' }
    end

    it 'returns the s3_prefix merged with the hash_output' do
      subject.s3_object(subject.hash_output).should == 'lollel'
    end
  end
end
