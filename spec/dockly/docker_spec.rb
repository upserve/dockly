require 'spec_helper'

describe Dockly::Docker do
  subject { described_class.new(:name => :test_docker) }

  describe '#ensure_tar' do
    let(:action) { subject.ensure_tar(file) }

    context 'when the file is not a tar' do
      let(:file) { __FILE__ }
      it 'raises an error' do
        expect { action }.to raise_error
      end
    end

    context 'when the file is gzipped' do
      let(:file) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'test-2.tar.gz') }

      it 'calls unzips it and calls #ensure_tar on result' do
        action.should == file
      end
    end

    context 'when the file is a tar' do
      let(:file) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'test-1.tar') }

      it 'returns the file name' do
        action.should == file
      end
    end
  end

  describe '#make_git_archive' do
    [:name, :git_archive].each do |ivar|
      context "when the #{ivar} is null" do
        before { subject.instance_variable_set(:"@#{ivar}", nil) }

        it 'raises an error' do
          expect { subject.make_git_archive }.to raise_error
        end
      end
    end

    context 'when both the name and git archive are specified' do
      before do
        subject.tag 'my-sweet-archive'
        subject.git_archive '/dev/random'
        FileUtils.rm(subject.git_archive_path) if File.exist?(subject.git_archive_path)
      end

      it 'makes a git archive' do
        expect { subject.make_git_archive }
            .to change { File.exist?(subject.git_archive_path) }
            .from(false)
            .to(true)

        names = []
        Gem::Package::TarReader.new(File.new(subject.git_archive_path, 'r')).each do |entry|
          names << entry.header.name
        end
        names.should include('/dev/random/dockly.gemspec')
      end
    end
  end

  describe '#import_base', :docker do
    let(:images) { [] }
    let(:docker_file_s3) { 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz' }
    let(:docker_file) { 'docker-export-ubuntu-latest.tar.gz' }
    let(:container) { Docker::Container.create('Image' => images.last.id, 'Cmd' => ['ls', '-1', '/']) }
    let(:output) { container.tap(&:start).attach(logs: true) }

    after do
      container.tap(&:wait).remove
      images.last.remove
    end

    # TODO: since we used to run this w/ Vagrant, we put it all together; break it up
    it 'works' do
      # it 'docker imports'
      subject.tag 'my-app'
      unless File.exist?(docker_file)
        File.open(docker_file, 'wb') do |file|
          Excon.get(docker_file_s3, response_block: lambda { |chunk, _, _| file.write(chunk) })
        end
      end
      images << subject.import_base(subject.ensure_tar(docker_file))
      expect(Docker::Image.all).to be_any do |image|
        image.info['RepoTags']
          .include?("my-app-base:dockly-#{Dockly::VERSION}-docker-export-ubuntu-latest")
      end
      expect(images.last).to_not be_nil
      expect(images.last.id).to_not be_nil

      # it 'builds'
      subject.build "run touch /lol"
      images << subject.build_image(images.last)
      expect(output[0].grep(/lol/)).to_not be_empty

      # it 'exports'
      subject.export_image(images.last)
      expect(File.exist?('build/docker/test_docker-image.tgz')).to be_true
    end

    context 'when the image has already been imported' do
      before { images << subject.import_base(docker_file) }

      it 'does not reimport the image' do
        expect(Docker::Image).to_not receive(:import)
        subject.import_base(docker_file)
      end
    end
  end

  describe '#fetch_import' do
    [:name, :import].each do |ivar|
      context "when @#{ivar} is nil" do
        before { subject.instance_variable_set(:"@#{ivar}", nil) }

        it 'raises an error' do
          expect { subject.fetch_import }.to raise_error
        end
      end
    end

    context 'when both import and name are present present' do
      before do
        subject.import url
        subject.tag 'test-name'
      end

      context 'and it points at S3' do
        let(:url) { 's3://bucket/object' }
        let(:data) { 'sweet, sweet data' }

        before do
          subject.send(:connection).put_bucket('bucket')
          subject.send(:connection).put_object('bucket', 'object', data)
        end

        it 'pulls the file from S3' do
          File.read(subject.fetch_import).should == data
        end
      end

      context 'and it points to a non-S3 url' do
        let(:url) { 'http://www.html5zombo.com' }

       before { subject.tag 'yolo' }

        it 'pulls the file', :vcr do
          subject.fetch_import.should be_a String
        end
      end

      context 'and it does not point at a url' do
        let(:url) { 'lol-not-a-real-url' }

        it 'raises an error' do
          expect { subject.fetch_import }.to raise_error
        end
      end
    end
  end

  describe "#export_image", :docker do
    let(:image) { Docker::Image.create('fromImage' => 'ubuntu:14.04') }

    context "with a registry export" do
      let(:registry) { double(:registry) }
      before do
        subject.instance_variable_set(:"@registry", registry)
        expect(subject).to receive(:push_to_registry)
      end

      it "pushes the image to the registry" do
        subject.export_image(image)
      end
    end

    context "with an S3 export" do
      let(:export) { double(:export) }
      before do
        expect(Dockly::AWS::S3Writer).to receive(:new).and_return(export)
        expect(export).to receive(:write).once
        expect(export).to receive(:close).once
        subject.s3_bucket "test-bucket"
      end

      context "and a whole export" do
        before do
          expect(subject).to receive(:export_image_whole)
        end

        it "exports the whole image" do
          subject.export_image(image)
        end
      end

      context "and a diff export" do
        before do
          subject.tar_diff true
          expect(subject).to receive(:export_image_diff)
        end

        it "exports the diff image" do
          subject.export_image(image)
        end
      end
    end

    context "with a file export" do
      let(:export) { double(:export) }
      before do
        expect(File).to receive(:open).and_return(export)
        expect(export).to receive(:write).once
        expect(export).to receive(:close)
      end

      context "and a whole export" do
        before do
          expect(subject).to receive(:export_image_whole)
        end

        it "exports the whole image" do
          subject.export_image(image)
        end
      end

      context "and a diff export" do
        before do
          subject.tar_diff true
          expect(subject).to receive(:export_image_diff)
        end

        it "exports the diff image" do
          subject.export_image(image)
        end
      end
    end
  end

  describe '#export_image_diff', :docker do
    let(:images) { [] }
    let(:output) { StringIO.new }
    let(:container) { images.last.run('true').tap { |c| c.wait(10) } }

    before do
      subject.instance_eval do
        import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-test.tgz'
        build "run touch /it_worked"
        repository "dockly_export_image_diff"
      end
    end

    after do
      container.remove
      images.last.remove
    end

    it "should export only the tar with the new file" do
      docker_tar = File.absolute_path(subject.ensure_tar(subject.fetch_import))

      images << subject.import_base(docker_tar)
      images << subject.build_image(images.last)
      subject.export_image_diff(container, output)

      expect(output.string).to include('it_worked')
      expect(output.string).to_not include('bin')
    end
  end

  describe '#generate!', :docker do
    let(:docker_file) { 'build/docker/dockly_test-image.tgz' }
    before { FileUtils.rm_rf(docker_file) }

    context 'with cleaning up' do
      before do
        subject.instance_eval do
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build "run touch /it_worked"
          repository 'dockly_test'
          build_dir 'build/docker'
          cleanup_images true
        end
      end

      it 'builds a docker image' do
        expect { subject.generate! }.to_not change { ::Docker::Image.all(:all => true).length }
        expect(File.exist?(docker_file)).to be_true
        expect(Dockly::Util::Tar.is_gzip?(docker_file)).to be_true
        expect(File.size(docker_file)).to be > (1024 * 1024)
        paths = []
        Gem::Package::TarReader.new(Zlib::GzipReader.new(File.new(docker_file))).each do |entry|
          paths << entry.header.name
        end
        expect(paths.size).to be > 1000
        expect(paths).to include('sbin/init')
        expect(paths).to include('lib/dockly.rb')
        expect(paths).to include('it_worked')
      end
    end

    context 'without cleaning up' do
      before do
        subject.instance_eval do
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build_env 'TEST_FILE' => 'it_worked'
          build "run touch $TEST_FILE"
          repository 'dockly_test'
          build_dir 'build/docker'
          cleanup_images false
        end
      end

      after do
        image = ::Docker::Image.all.find do |image|
          image.info['RepoTags'].include?('dockly_test:latest')
        end
        image.remove if image
      end

      it 'builds a docker image' do
        expect { subject.generate! }.to change { ::Docker::Image.all(:all => true).length }.by(4)

        expect(File.exist?(docker_file)).to be_true
        expect(Dockly::Util::Tar.is_gzip?(docker_file)).to be_true
        expect(File.size(docker_file)).to be > (1024 * 1024)
        paths = []
        Gem::Package::TarReader.new(Zlib::GzipReader.new(File.new(docker_file))).each do |entry|
          paths << entry.header.name
        end
        expect(paths.size).to be > 1000
        expect(paths).to include('sbin/init')
        expect(paths).to include('lib/dockly.rb')
        expect(paths).to include('it_worked')
      end
    end

    context 'when there is a registry' do
      subject {
        Dockly::Docker.new do
          registry_import 'tianon/true', :tag => 'latest'
          git_archive '.'
          build 'RUN ["/true", ""]'
          repository 'dockly_test'
          build_dir 'build/docker'

          registry do
            username ENV['DOCKER_USER']
            email ENV['DOCKER_EMAIL']
            password ENV['DOCKER_PASS']
          end
        end
      }

      it 'pushes the image to the registry instead of exporting it' do
        image = subject.generate_build
        expect { ::Docker::Image.build("from #{ENV['DOCKER_USER']}/dockly_test") }.to_not raise_error
        image.remove unless image.nil?
      end
    end
  end
end
