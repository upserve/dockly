require 'spec_helper'

describe Dockly::Util::Git do
  describe '#repo' do
    it 'returns the repo for the current directory' do
      expect(subject.repo.git_work_tree).to eq(File.expand_path('.'))
    end
  end

  describe '#sha' do
    it 'returns a sha for the head object' do
      expect(subject.sha).to eq(`git rev-parse HEAD`.strip)
    end
  end

  describe '#archive' do
    let(:io) { StringIO.new }
    let(:prefix) { '/gem/dockly' }
    let(:reader) { Gem::Package::TarReader.new(io.tap(&:rewind)) }

    it 'archives the current directory into the given IO' do
      subject.archive(subject.sha, prefix, io)
      reader.each do |entry|
        if entry.full_name == 'pax_global_header'
          expect(entry.header.typeflag).to eq('g')
        else
          expect(entry.full_name).to start_with(prefix)
          orig = entry.full_name.gsub(/\A#{prefix}/, '.')
          expect(File.exist?(orig)).to be_true
          expect(entry.read).to eq(File.read(orig)) if orig.end_with?('.rb')
        end
      end
    end

    context 'with a really long prefix' do
      let(:prefix) { '/' + ('a' * 255) }
      it 'exhibits the tar extended headers' do
        subject.archive(subject.sha, prefix, io)
        expect(io.string.include?("path=#{prefix}")).to be true
      end
    end
  end
end
