require 'spec_helper'
require 'tempfile'

describe Dockly::Deb do
  describe '#create_package!' do
    subject do
      Dockly::Deb.new do
        package_name 'my-sweet-deb'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build'
      end
    end
    let(:filename) { "build/deb/my-sweet-deb_77.0.8_x86_64.deb" }
    #after { FileUtils.rm_rf(filename) }

    [:package_name, :version, :release, :arch, :build_dir].each do |ivar|
      context "when the #{ivar} is nil" do
        before { subject.instance_variable_set(:"@#{ivar}", nil) }
        it 'raises an error' do
          expect { subject.create_package }.to raise_error
        end
      end
    end

    context 'when it has a foreman export' do
      before do
        subject.foreman do
          name 'foreman'
          init_dir '/etc/systemd/system'
          build_dir 'build/foreman'
          procfile File.join(File.dirname(__FILE__), '..', 'fixtures', 'Procfile')
          user 'root'
          type 'systemd'
          prefix '/bin/sh'
        end
      end

      it 'export the foreman to the deb' do
        subject.create_package!
        `dpkg --contents #{filename}`
            .lines.grep(/foreman/).should_not be_empty
      end
    end

    context 'when it has a docker', :docker do
      before do
        subject.docker do
          name 'deb_test'
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build 'touch /deb_worked'
          build_dir 'build/docker'
        end
      end

      it 'builds the docker image and adds it to the deb' do
        subject.create_package!
        `dpkg --contents #{filename}`
            .lines.grep(/deb_test-image\.tgz/).should_not be_empty
      end
    end

    context 'when it has a docker with registry', :docker do
      before do
        subject.docker do
          name 'deb_test'
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build 'touch /deb_worked'
          build_dir 'build/docker'

          registry :test_docker_registry do
            auth_config_file '/etc/docker/.dockercfg'
            username 'tlunter'
            email 'tlunter@gmail.com'
            password '******'
          end
        end
      end

      it 'builds the docker image and adds it to the deb' do
        subject.create_package!
        `dpkg --contents #{filename}`
            .lines.grep(/.dockercfg/).should_not be_empty
      end
    end

    context 'when it has files' do
      let(:file1) { Tempfile.new('files') }
      let(:file2) { Tempfile.new('files') }
      let(:contents) { `dpkg --contents #{filename}` }

      before do
        subject.file file1.path, '/etc/file1'
        subject.file file2.path, '/etc/file2'
        subject.file './lib/dockly/.', '/etc/deploys'
        subject.file './lib/foreman/', '/etc/foreman'
        subject.file './spec', '/etc/specs'
      end

      after do
        file1.close
        file1.unlink

        file2.close
        file2.unlink
      end

      it 'adds the file to deb' do
        subject.create_package!
        expect(contents.lines.grep(/\/etc\/file1/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/file2/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/deploys\/deb.rb/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/foreman\/foreman\/cli_fix.rb/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/specs\/spec\/dockly_spec.rb/)).to_not be_empty
      end
    end

    context 'when there is no docker or foreman export' do
      it 'does nothing with docker or foreman' do
        subject.docker.should_not_receive(:generate!)
        subject.foreman.should_not_receive(:create!)
        subject.create_package!
      end

      it 'creates a deb package' do
        subject.create_package!
        File.exist?(subject.build_path).should be_true
      end
    end
  end

  describe '#exists?' do
    subject do
      Dockly::Deb.new do
        package_name 'deb-4-u-buddy'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/deb/s3'
      end
    end

    context 'when the object does exist' do
      before do
        Dockly::AWS.s3.stub(:head_object).and_return {}
      end

      it 'is true' do
        expect(subject.exists?).to be_true
      end
    end

    context 'when the object does not exist' do
      before do
        Dockly::AWS.s3.stub(:head_object).and_raise(Excon::Errors::NotFound.new "NotFound")
      end

      it 'is true' do
        expect(subject.exists?).to be_false
      end
    end
  end

  describe '#upload_to_s3' do
    subject do
      Dockly::Deb.new do
        package_name 'deb-4-u-buddy'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/deb/s3'
      end
    end

    context 'when the s3_bucket is nil' do
      it 'does nothing' do
        Dockly::AWS.should_not_receive(:s3)
        subject.upload_to_s3
      end
    end

    context 'when the s3_bucket is present' do
      let(:bucket_name) { 'swerve_bucket' }
      before { subject.s3_bucket(bucket_name) }

      context 'when the package has yet to be created' do
        before { FileUtils.rm(subject.build_path) rescue nil }

        it 'raises an error' do
          expect { subject.upload_to_s3 }.to raise_error
        end
      end

      context 'when the package has been created' do
        before { subject.create_package! }

        it 'creates the s3 bucket' do
          subject.upload_to_s3
          Dockly::AWS.s3.get_bucket(bucket_name).body.should_not be_nil
        end

        it 'inserts the deb package into that bucket' do
          subject.upload_to_s3
          Dockly::AWS.s3.get_bucket(bucket_name, subject.s3_object_name).body.should_not be_nil
        end
      end
    end
  end

  describe "#file" do
    subject do
      Dockly::Deb.new do
        package_name 'my-sweet-deb'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/deb'
      end
    end

    before do
      subject.files []
    end

    it 'adds a hash of source and destination to the files list' do
      subject.file('nginx.conf', '/etc/nginx.conf')
      expect(subject.files).to eq([
        {
          :source => 'nginx.conf',
          :destination => '/etc/nginx.conf'
        }
      ])
    end
  end

  describe '#build' do
    subject do
      Dockly::Deb.new do
        package_name 'my-sweet-deb'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/deb'
      end
    end

    it 'calls create_package! and upload_to_s3' do
      subject.should_receive(:create_package!)
      subject.should_receive(:upload_to_s3)
      subject.build
    end
  end
end
