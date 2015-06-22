require 'spec_helper'

describe Dockly::History do
  describe '#duplicate_build?' do
    before { allow(subject).to receive(:duplicate_build_sha).and_return(sha) }

    context 'when the duplicate build sha is not present' do
      let(:sha) { nil }

      it 'returns false' do
        expect(subject).to_not be_duplicate_build
      end
    end

    context 'when the duplicate build sha is present' do
      let(:sha) { 'DEADBEEF' }

      it 'returns true' do
        expect(subject).to be_duplicate_build
      end
    end
  end

  describe '#duplicate_build_sha' do
    let(:content_tag) { 'dockly-FAKE-CONTENT-HASH' }

    before { allow(subject).to receive(:content_tag).and_return(content_tag) }

    context 'when there is not a commit with a matching content hash' do
      it 'returns nil' do
        expect(subject.duplicate_build_sha).to be(nil)
      end
    end

    context 'when there is a commit with a matching content hash' do
      let(:sha) { 'dockly-FAKE-SHA' }
      let(:key) { content_tag }

      before { subject.tags[key] = sha }
      after { subject.tags.delete(key) }

      it 'returns that commit' do
        expect(subject.duplicate_build_sha).to eq(sha)
      end
    end
  end

  describe '#tags' do
    let(:expected) do
      {
        'v1.4.0' => '708b4f1bd7846c258e2151e34f8f746b399ee6fb',
        'v1.4.2' => '20b62fa084ac903a8753cfc7939c7e31c86761d2',
        'v1.4.3' => '8eac23450975d91f0aa4c62c6985ec4f4ce7594f'
      }
    end

    it 'returns a Hash of the git tags' do
      expected.each do |tag, oid|
        expect(subject.tags[tag]).to include(oid)
      end
    end
  end

  describe '#ls_files' do
    let(:files) { subject.ls_files }

    it 'returns the files checked into the repo' do
      expect(files).to be_a(Array)
      expect(files).to include('dockly.gemspec')
      expect(files).to include('lib/dockly.rb')
      expect(files).to include('spec/dockly/aws/s3_writer_spec.rb')
    end
  end

  describe '#content_hash_for' do
    context 'when two hashes are compared' do
      let(:hash_one) { subject.content_hash_for(%w(dockly.gemspec Gemfile)) }
      let(:hash_two) { subject.content_hash_for(%w(lib/dockly.rb LICENSE.txt)) }

      it 'creates a unique hash for the given paths' do
        expect(hash_one).to_not eq(hash_two)
      end
    end

    context 'when the paths are in a different order' do
      let(:hash_one) { subject.content_hash_for(%w(dockly.gemspec Gemfile)) }
      let(:hash_two) { subject.content_hash_for(%w(Gemfile dockly.gemspec)) }

      it 'still creates the same hash' do
        expect(hash_one).to eq(hash_two)
      end
    end
  end
end
