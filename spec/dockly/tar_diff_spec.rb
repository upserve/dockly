require 'spec_helper'

describe Dockly::TarDiff do
  let(:base) { StringIO.new }
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  subject { described_class.new(base, input, output) }

  describe "#quick_write" do
    let(:input) { StringIO.new(message) }

    context "for a message under 4096 bytes" do
      let(:message) { "\0" * 100 }

      it "reads and writes only once" do
        input.should_receive(:read).once.and_call_original
        subject.quick_write(message.size)
      end
    end

    context "for a message over 4096 bytes" do
      let(:message) { "\0" * 4097 }

      it "reads and writes only once" do
        input.should_receive(:read).twice.and_call_original
        subject.quick_write(message.size)
      end
    end
  end

  describe "#write_tar_section" do
    let(:header) { "ab" }
    let(:message) { "cd" }
    let(:input) { StringIO.new(message) }
    let(:size) { message.size }
    let(:remainder) { 3 }
    let(:output_message) { "abcd\0\0\0" }

    it "it writes the header, size length message and remainder to the output" do
      subject.write_tar_section(header, size, remainder)
      expect(output.string).to be == output_message
    end
  end

  describe "#read_header" do
    let(:input) { File.open("spec/fixtures/test-3.tar") }

    it "with a tar with 2 files should yield exactly four times; 2 files + 2 512 byte null blocks" do
      expect do |b|
        block = b.to_proc
        subject.read_header(input) do |*args|
          block.call(*args)

          data, name, prefix, mtime, size, remainder, empty = args

          case b.num_yields
          when 1
            expect(name).to be == "Rakefile"
          when 2
            expect(name).to be == "Procfile"
          when 3
            expect(empty).to be_true
          when 4
            expect(empty).to be_true
          else
            raise "Failed"
          end

          input.read(size)
        end
      end.to yield_control.exactly(4).times
    end
  end

  describe "#process" do
    let(:base) { File.open('spec/fixtures/test-1.tar') }
    let(:input) { File.open('spec/fixtures/test-3.tar') }

    it "only adds the new file to the output" do
      subject.process
      expect(output.string).to include("Procfile")
      expect(output.string).to_not include("Rakefile")
    end
  end
end
