require 'spec_helper'
require 'tempfile'

describe Dockly::Rpm do
  describe '#create_package!' do
    subject do
      Dockly::Rpm.new do
        package_name 'my-sweet-rpm'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build'
      end
    end
    let(:filename) { "build/rpm/my-sweet-rpm_77.0.8_x86_64.rpm" }
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

      it 'export the foreman to the rpm' do
        subject.create_package!
        `rpm -qpl #{filename}`
            .lines.grep(/foreman/).should_not be_empty
      end
    end

    context 'when it has a docker', :docker do
      before do
        subject.docker do
          name 'rpm_test'
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build 'RUN touch /rpm_worked'
          build_dir 'build/docker'
        end
      end

      after do
        image = ::Docker::Image.all.find do |image|
          image.info['RepoTags'].include?('rpm_test:latest')
        end
        image.remove if image
      end

      it 'builds the docker image and adds it to the rpm' do
        subject.create_package!
        `rpm -qpl #{filename}`
            .lines.grep(/rpm_test-image\.tgz/).should_not be_empty
      end
    end

    context 'when it has a docker with registry', :docker do
      before do
        subject.docker do
          name 'rpm_test'
          import 'https://s3.amazonaws.com/swipely-pub/docker-export-ubuntu-latest.tgz'
          git_archive '.'
          build 'RUN touch /rpm_worked'
          build_dir 'build/docker'

          registry :test_docker_registry do
            auth_config_file '/etc/docker/.dockercfg'
            username ENV['DOCKER_USER']
            email ENV['DOCKER_EMAIL']
            password ENV['DOCKER_PASS']
          end
        end
      end

      after do
        image = ::Docker::Image.all.find do |image|
          image.info['RepoTags'].include?("#{ENV['DOCKER_USER']}/rpm_test:latest")
        end
        image.remove if image
      end

      it 'builds the docker image and adds it to the rpm' do
        subject.create_package!
        `rpm -qpl #{filename}`
            .lines.grep(/.dockercfg/).should_not be_empty
      end
    end

    context 'when it has files' do
      let(:file1) { Tempfile.new('files') }
      let(:file2) { Tempfile.new('files') }
      let(:contents) { `rpm -qpl #{filename}` }

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

      it 'adds the file to rpm' do
        subject.create_package!
        expect(contents.lines.grep(/\/etc\/file1/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/file2/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/deploys\/rpm.rb/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/foreman\/foreman\/cli_fix.rb/)).to_not be_empty
        expect(contents.lines.grep(/\/etc\/specs\/spec\/dockly_spec.rb/)).to_not be_empty
      end
    end

    context 'when there is no docker or foreman export' do
      let(:output) { `rpm -qpl #{filename}` }
      it 'does nothing with docker or foreman' do
        subject.foreman.should_not_receive(:create!)
        subject.create_package!
        expect(output).to_not include("rpm_test-image.tgz")
        expect(output).to_not include("/etc/systemd")
        expect(output).to_not include("/etc/init")
      end

      it 'creates a rpm package' do
        subject.create_package!
        File.exist?(subject.build_path).should be_true
      end
    end

    it "places a startup script in the package" do
      subject.create_package!
      expect(`rpm -qpl #{filename}`).to include("dockly-startup.sh")
    end

    context 'when package_startup_script is false' do
      before { subject.package_startup_script(false) }

      it 'does not place a startup script in the package' do
        subject.create_package!
        expect(`rpm -qpl #{filename}`).to_not include("dockly-startup.sh")
      end
    end
  end

  describe '#exists?' do
    subject do
      Dockly::Rpm.new do
        package_name 'rpm-4-u-buddy'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/rpm/s3'
      end
    end

    context 'when the object does exist' do
      before do
        allow(Dockly.s3)
          .to receive(:head_object)
          .and_return({})
      end

      it 'is true' do
        expect(subject.exists?).to be_true
      end
    end

    context 'when the object does not exist' do
      before do
        allow(Dockly.s3)
          .to receive(:head_object)
          .and_raise(StandardError.new('object does not exist'))
      end

      it 'is true' do
        expect(subject.exists?).to be_false
      end
    end
  end

  describe '#upload_to_s3' do
    subject do
      Dockly::Rpm.new do
        package_name 'rpm-4-u-buddy'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/rpm/s3'
      end
    end

    context 'when the s3_bucket is nil' do
      it 'does nothing' do
        expect(Dockly).to_not receive(:s3)
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

        it 'inserts the rpm package into that bucket' do
          expect(Dockly.s3).to receive(:put_object) do |hash|
            expect(hash[:bucket]).to eq(bucket_name)
            expect(hash[:key]).to eq(subject.s3_object_name)
            expect(hash).to have_key(:body)
          end

          subject.upload_to_s3
        end
      end
    end
  end

  describe "#file" do
    subject do
      Dockly::Rpm.new do
        package_name 'my-sweet-rpm'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/rpm'
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
      Dockly::Rpm.new do
        package_name 'my-sweet-rpm'
        version '77.0'
        release '8'
        pre_install "ls"
        post_install "rd /s /q C:\*"
        build_dir 'build/rpm'
      end
    end

    it 'calls create_package! and upload_to_s3' do
      subject.should_receive(:create_package!)
      subject.should_receive(:upload_to_s3)
      subject.build
    end
  end
end
