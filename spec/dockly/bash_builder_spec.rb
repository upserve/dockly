require 'spec_helper'

describe Dockly::BashBuilder do
  describe "#normalize_for_dockly" do
    it "sets up log and fatal and makes /opt/dockly" do
      output = subject.normalize_for_dockly
      expect(output).to include("function log")
      expect(output).to include("function fatal")
      expect(output).to include("mkdir -p /opt/dockly")
    end
  end

  describe "#get_from_s3" do
    let(:s3_url) { "s3://url-for-s3/file.tar.gz" }
    context "uses the default output" do 
      it "polls from s3 and sets the s3_path" do
        output = subject.get_from_s3(s3_url)
        expect(output).to include("s3cmd -f get $s3_path $output_path")
        expect(output).to include("s3_path=\"#{s3_url}\"")
        expect(output).to include("output_path=\"-\"")
      end
    end
    context "uses a specific output directory" do
      let(:output_dir) { "test" }
      it "polls from s3 and sets the s3_path and output_path" do
        output = subject.get_from_s3(s3_url, output_dir)
        expect(output).to include("s3cmd -f get $s3_path $output_path")
        expect(output).to include("s3_path=\"#{s3_url}\"")
        expect(output).to include("output_path=\"#{output_dir}\"")
      end
    end
  end

  describe "#install_package" do
    let(:path) { "/opt/dockly/deb.deb" }
    it "installs from the given path" do
      output = subject.install_package(path)
      expect(output.strip).to eq("dpkg -i \"#{path}\"")
    end
  end

  describe "#get_and_install_deb" do
    let(:s3_url) { "s3://bucket/path-to-deb.deb" }
    let(:deb_path) { "/opt/dockly/deb_path.deb" }
    it "gets from s3 and installs the package" do
      expect(subject).to receive(:get_from_s3).with(s3_url, deb_path)
      expect(subject).to receive(:install_package).with(deb_path)
      subject.get_and_install_deb(s3_url, deb_path)
    end
  end

  describe "#docker_import" do
    context "when not given a repo" do
      it "imports with no tagging" do
        output = subject.docker_import
        expect(output).to include("docker import -")
      end
    end

    context "when given a repo" do
      let(:repo) { "aRepo" }
      it "imports with repo and latest" do
        output = subject.docker_import(repo)
        expect(output).to include("docker import - #{repo}:latest")
      end

      context "and a non-default tag" do
        let(:tag) { "aTag" }
        it "imports with repo and the tag" do
          output = subject.docker_import(repo, tag)
          expect(output).to include("docker import - #{repo}:#{tag}")
        end
      end
    end
  end

  describe "#file_docker_import" do
    let(:path) { "/opt/dockly/file.tar.gz" }
    it "cats, gunzips and passes to docker import" do
      expect(subject).to receive(:docker_import)
      output = subject.file_docker_import(path)
      expect(output).to include("cat")
      expect(output).to include("gunzip -c")
    end
  end

  describe "#file_diff_docker_import" do
    let(:base_image) { "s3://bucket/base_image.tar.gz" }
    let(:diff_image) { "/opt/dockly/diff_image.tar.gz" }
    it "gets the base file from S3 and cats that with the diff image and imports to docker" do
      expect(subject).to receive(:get_from_s3).with(base_image)
      expect(subject).to receive(:docker_import)
      expect(subject.file_diff_docker_import(base_image, diff_image)).to include("cat \"#{diff_image}\"")
    end
  end

  describe "#s3_docker_import" do
    let(:s3_url) { "s3://bucket/image.tar.gz" }
    it "pulls, gunzips and passes to docker import" do
      expect(subject).to receive(:get_from_s3)
      expect(subject).to receive(:docker_import)
      output = subject.s3_docker_import(s3_url)
      expect(output).to include("gunzip -c")
    end
  end

  describe "#s3_diff_docker_import" do
    let(:base_image) { "s3://bucket/base_image.tar.gz" }
    let(:diff_image) { "s3://bucket/diff_image.tar.gz" }
    it "makes two functions for getting from s3, finds the size, and imports both to docker" do
      expect(subject).to receive(:get_from_s3).twice
      expect(subject).to receive(:docker_import)
      output = subject.s3_diff_docker_import(base_image, diff_image)
      expect(output).to include("stat -f \"%z\"")    # get file size
      expect(output).to include("$(($size - 1024))") # compute file size
      expect(output).to include("head -c $head_size")
      expect(output).to include("gunzip")
    end
  end

  describe "#registry_import" do
    let(:repo) { "aRepo" }
    context "not given a tag" do
      it "pulls the latest" do
        output = subject.registry_import(repo)
        expect(output).to include("docker pull #{repo}:latest")
      end
    end

    context "given a tag" do
      let(:tag) { "aTag" }
      it "pulls to specified tag" do
        output = subject.registry_import(repo, tag)
        expect(output).to include("docker pull #{repo}:#{tag}")
      end
    end
  end
end
