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

  describe "#get_and_install_deb" do
    let(:s3_url) { "s3://bucket/path-to-deb.deb" }
    let(:deb_path) { "/opt/dockly/deb_path.deb" }
    it "gets from s3 and installs the package" do
      output = subject.get_and_install_deb(s3_url, deb_path)
      expect(output).to include(s3_url)
      expect(output).to include(deb_path)
      expect(output).to include("aws s3 cp --quiet")
      expect(output).to include("dpkg -i")
    end
  end

  describe "#docker_tag_latest" do
    context "when there is no tag" do
      it "does not mark a tag" do
        output = subject.docker_tag_latest("test_repo")
        expect(output).to_not include("docker tag")
      end
    end

    context "when there is a tag" do
      it "tags the repo:tag as repo:latest" do
        output = subject.docker_tag_latest("registry/test_repo", "a_tag", "test_repo")
        expect(output).to include("docker tag registry/test_repo:a_tag test_repo:latest")
      end
    end
  end

  describe "#file_docker_import" do
    let(:path) { "/opt/dockly/file.tar.gz" }
    it "cats, gunzips and passes to docker import" do
      output = subject.file_docker_import(path)
      expect(output).to include("cat")
      expect(output).to include("gunzip -c")
      expect(output).to include("docker import -")
    end
  end

  describe "#file_diff_docker_import" do
    let(:base_image) { "s3://bucket/base_image.tar.gz" }
    let(:diff_image) { "/opt/dockly/diff_image.tar.gz" }
    it "gets the base file from S3 and cats that with the diff image and imports to docker" do
      output = subject.file_diff_docker_import(base_image, diff_image)
      expect(output).to include(base_image)
      expect(output).to include(diff_image)
      expect(output).to include("cat \"#{diff_image}\"")
      expect(output).to include("aws s3 cp --quiet")
      expect(output).to include("docker import -")
    end
  end

  describe "#s3_docker_import" do
    let(:s3_url) { "s3://bucket/image.tar.gz" }
    it "pulls, gunzips and passes to docker import" do
      output = subject.s3_docker_import(s3_url)
      expect(output).to include(s3_url)
      expect(output).to include("gunzip -c")
      expect(output).to include("aws s3 cp --quiet")
      expect(output).to include("docker import -")
    end
  end

  describe "#s3_diff_docker_import" do
    let(:base_image) { "s3://bucket/base_image.tar.gz" }
    let(:diff_image) { "s3://bucket/diff_image.tar.gz" }
    it "makes two functions for getting from s3, finds the size, and imports both to docker" do
      output = subject.s3_diff_docker_import(base_image, diff_image)
      expect(output).to include(base_image)
      expect(output).to include(diff_image)
      expect(output).to include("stat --format \"%s\"")    # get file size
      expect(output).to include("$(($size - 1024))") # compute file size
      expect(output).to include("head -c $head_size")
      expect(output).to include("gunzip")
      expect(output).to include("aws s3 cp --quiet")
      expect(output).to include("docker import -")
    end
  end

  describe "#registry_import" do
    let(:repo) { "aRepo" }
    context "not given a tag" do
      it "pulls the latest" do
        output = subject.registry_import(repo)
        expect(output).to include("docker pull $repo:$tag")
        expect(output).to include("repo=#{repo}")
        expect(output).to include("tag=latest")
      end
    end

    context "given a tag" do
      let(:tag) { "aTag" }
      it "pulls to specified tag" do
        output = subject.registry_import(repo, tag)
        expect(output).to include("docker pull $repo:$tag")
        expect(output).to include("repo=#{repo}")
        expect(output).to include("tag=#{tag}")
      end
    end
  end
end
