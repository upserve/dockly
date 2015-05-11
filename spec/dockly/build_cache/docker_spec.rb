require 'spec_helper'

describe Dockly::BuildCache::Docker, :docker do
  let!(:build_cache) { described_class.new!(:name => :test_build_cache) }
  let!(:docker) do
    Dockly::Docker.new!(:name => :test_docker) do
      git_archive '/app'
    end
  end
  let(:image) { ::Docker::Image.build('from ubuntu') }

  before do
    build_cache.s3_bucket 'lol'
    build_cache.s3_object_prefix 'swag'
    build_cache.image = image
    build_cache.hash_command 'md5sum /etc/vim/vimrc'
    build_cache.build_command 'touch lol'
    build_cache.output_dir '/etc/vim'
    build_cache.base_dir '/'
    build_cache.keep_old_files true
    docker.build_cache :test_build_cache
  end

  describe "#initialize" do
    context "base_dir is the docker git_archive" do
      before do
        build_cache.instance_variable_set(:@base_dir, nil)
      end

      it "should return the base_directory as the git_archive" do
        expect(build_cache.base_directory).to eq(docker.git_archive)
      end
    end
  end

  describe '#execute!' do
    before do
      build_cache.stub(:up_to_date?).and_return(up_to_date)
      build_cache.stub(:push_cache)
      build_cache.stub(:push_to_s3)
    end

    context 'when the object is up to date' do
      let(:up_to_date) { true }

      it "does not have the file lol" do
        i = build_cache.execute!
        output = ""
        i.run('ls').attach { |source,chunk| output += chunk }
        output.should_not include('lol')
      end
    end

    context 'when the object is not up to date' do
      let(:up_to_date) { false }

      before do
        build_cache.stub(:copy_output_dir) { StringIO.new }
      end

      it "does have the file lol" do
        i = build_cache.execute!
        output = i.run('ls /').attach(:stdout => true)
        output.first.first.lines.map(&:chomp).should include('lol')
      end
    end
  end

  describe "#run_build" do
    before do
      build_cache.stub(:push_to_s3)
    end

    context "when the build succeeds" do
      it "does have the file lol" do
        i = build_cache.run_build
        output = ""
        i.run('ls').attach { |source,chunk| output += chunk }
        output.should include('lol')
      end
    end

    context "when the build fails" do
      let!(:image) { build_cache.image }
      before do
        build_cache.image = double(:image).stub(:run) {
          stub(:container, { :wait => { 'StatusCode' => 1 } })
        }
      end

      after do
        build_cache.image = image
      end

      it "raises an error" do
        expect { build_cache.run_build }.to raise_error
      end
    end
  end

  describe '#hash_output' do
    let(:output) {
      "682aa2a07693cc27756eee9751db3903  /etc/vim/vimrc"
    }

    context "when hash command returns successfully" do
      before do
        build_cache.image = image
      end

      it 'returns the output of the hash_command in the container' do
        build_cache.hash_output.should == output
      end
    end

    context "when hash command returns failure" do
      before do
        build_cache.image = double(:image).stub(:run, {
          :wait => { 'StatusCode' => 1 }
        })
      end

      it 'raises an error' do
        expect { build_cache.hash_output }.to raise_error
      end
    end
  end

  describe '#copy_output_dir' do
    let(:container) { Docker::Container.create('Image' => 'ubuntu', 'Cmd' => %w[true]) }
    let(:file) { build_cache.copy_output_dir(container) }
    let(:hash) { 'this_really_unique_hash' }
    let(:path) { file.path }

    before do
      build_cache.stub(:hash_output).and_return(hash)
      build_cache.output_dir '/root/'; container.wait
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

  describe '#parameter_output' do
    before do
      build_cache.parameter_command command
    end

    context "when parameter command returns successfully" do
      let(:command) { "uname -r" }
      it 'returns the output of the parameter_command' do
        expect(build_cache.parameter_output(command)).to match(/\A3\.\d{2}\.\d-\d-ARCH\Z/)
      end
    end

    context "when parameter command returns failure" do
      let(:command) { 'md6sum' }

      it 'raises an error' do
        expect { build_cache.parameter_output(command) }.to raise_error
      end
    end

    context "when a parameter command isn't previously added" do
      let(:command) { "md5sum /etc/vim/vimrc" }

      it 'raises an error' do
        expect { build_cache.parameter_output("#{command}1") }.to raise_error
      end
    end
  end
end

