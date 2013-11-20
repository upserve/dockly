require 'spec_helper'

describe Dockly::BuildCache::Local do
  let(:build_cache) { described_class.new!(:name => :test_local_build_cache) }

  before do
    build_cache.s3_bucket 'fake'
    build_cache.s3_object_prefix 'object'
    build_cache.hash_command "md5sum #{File.join(Dir.pwd, 'Gemfile')} | awk '{ print $1 }'"
    build_cache.build_command 'touch lol'
    build_cache.output_dir 'lib'
  end

  describe '#execute!' do
    before do
      build_cache.stub(:hash_output).and_return('abcdef')
      build_cache.stub(:up_to_date?).and_return(up_to_date)
      build_cache.stub(:push_cache)
      build_cache.stub(:push_to_s3)

      if File.exist?('lol')
        File.delete('lol')
      end
    end

    context 'when the object is up to date' do
      let(:up_to_date) { true }

      it "does not have the file lol" do
        i = build_cache.execute!
        output = ""
        IO.popen('ls') { |io| output += io.read }
        output.should_not include('lol')
      end
    end

    context 'when the object is not up to date' do
      let(:up_to_date) { false }

      before do
        build_cache.stub(:copy_output_dir) { StringIO.new }
      end

      after do
        if File.exist?('lol')
          File.delete('lol')
        end
      end

      it "does have the file lol" do
        i = build_cache.execute!
        output = ""
        IO.popen('ls') { |io| output << io.read }
        output.should include('lol')
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
        IO.popen('ls') { |io| output << io.read }
        output.should include('lol')
      end
    end

    context "when the build fails" do
      before do
        build_cache.build_command 'md6sum'
      end

      it "raises an error" do
        expect { build_cache.run_build }.to raise_error
      end
    end
  end

  describe '#hash_output' do
    let(:output) {
      "f683463a09482287c33959ab71a87189"
    }

    context "when hash command returns successfully" do
      it 'returns the output of the hash_command in the container' do
        build_cache.hash_output.should == output
      end
    end

    context "when hash command returns failure" do
      before do
        build_cache.hash_command 'md6sum'
      end

      it 'raises an error' do
        expect { build_cache.hash_output }.to raise_error
      end
    end
  end
end
