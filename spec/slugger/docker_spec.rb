require 'spec_helper'

describe Slugger::Docker do
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
        names.should include('/dev/random/slugger.gemspec')
      end
    end
  end

  describe '#import_base', :docker do
    let(:docker_file) { 'docker-export-ubuntu-latest.tar.gz' }

    # TODO: since we used to run this w/ Vagrant, we put it all together; break it up
    it 'works' do
      # it 'docker imports'
      subject.tag 'my-app'
      unless File.exist?(docker_file)
        File.open(docker_file, 'wb') do |file|
          Excon.get('https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz',
                    :response_block => lambda { |chunk, _, _| file.write(chunk) })
        end
      end
      image = subject.import_base(subject.ensure_tar(docker_file))
      image.should_not be_nil
      image.id.should_not be_nil

      # it 'builds'
      subject.build "run touch /lol"
      image = subject.build_image(image)
      container = Docker::Container.create('Image' => image.id, 'Cmd' => ['ls', '-1', '/'])
      output = container.tap(&:start).attach(:stream => true, :stdout => true, :stderr => true)
      puts "output: #{output}"
      output.lines.grep(/lol/).should_not be_empty
      # TODO: stop resetting the connection, once no longer necessary after attach
      Docker.reset_connection!
      subject.instance_variable_set(:@connection, Docker.connection)

      # it 'exports'
      subject.export_image(image)
      File.exist?('build/docker/slugger-my-app-image.tgz').should be_true
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

  describe '#generate!', :docker do
    let(:docker_file) { 'build/docker/slugger_test-generate-image.tgz' }
    before { FileUtils.rm_rf(docker_file) }

    context 'without cleaning up' do
      before do
        subject.instance_eval do
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build "run touch /it_worked"
          repo 'slugger_test'
          tag 'generate'
          build_dir 'build/docker'
          cleanup_images false
        end
      end
      it 'builds a docker image' do
        expect {
          subject.generate!
          File.exist?(docker_file).should be_true
          Slugger::Util.is_gzip?(docker_file).should be_true
          File.size(docker_file).should be > (1024 * 1024)
          paths = []
          Gem::Package::TarReader.new(gz = Zlib::GzipReader.new(File.new(docker_file))).each do |entry|
            paths << entry.header.name
          end
          paths.size.should be > 1000
          paths.should include('./sbin/init')
          paths.should include('./lib/slugger.rb')
          paths.should include('./it_worked')
        }.to change { ::Docker::Image.all(:all => true).length }.by(3)
      end
    end

    context 'with cleaning up' do
      before do
        subject.instance_eval do
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build "run touch /it_worked"
          repo 'slugger_test'
          tag 'generate'
          build_dir 'build/docker'
          cleanup_images true
        end
      end
      it 'builds a docker image' do
        expect {
          subject.generate!
          File.exist?(docker_file).should be_true
          Slugger::Util.is_gzip?(docker_file).should be_true
          File.size(docker_file).should be > (1024 * 1024)
          paths = []
          Gem::Package::TarReader.new(gz = Zlib::GzipReader.new(File.new(docker_file))).each do |entry|
            paths << entry.header.name
          end
          paths.size.should be > 1000
          paths.should include('./sbin/init')
          paths.should include('./lib/slugger.rb')
          paths.should include('./it_worked')
        }.to change { ::Docker::Image.all(:all => true).length }.by(0)
      end
    end
  end
end

