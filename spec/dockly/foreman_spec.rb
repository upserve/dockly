require 'spec_helper'

describe Dockly::Foreman do
  describe '#create!' do
    subject do
      Dockly::Foreman.new do
        name :foreman
        init_dir '/etc/systemd/system'
        build_dir 'build/foreman'
        procfile File.join(File.dirname(__FILE__), '..', 'fixtures', 'Procfile')
        user 'root'
        type 'systemd'
        prefix '/bin/sh'
      end
    end

    [:init_dir, :build_dir, :procfile, :user, :type].each do |ivar|
      context "when the #{ivar} is nil" do
        before { subject.instance_variable_set(:"@#{ivar}", nil) }

        it 'raises an error' do
          expect { subject.create! }.to raise_error
        end
      end
    end

    context 'when all of the required variables are present' do
      it 'makes the upstart scripts' do
        subject.create!
        File.exist?('build/foreman/foreman.target').should be_true
        File.exist?('build/foreman/foreman-web.target').should be_true
        File.exist?('build/foreman/foreman-web@.service').should be_true
        File.open('build/foreman/foreman-web@.service')
            .grep(/^ExecStart=\/bin\/bash -lc 'exec \/bin\/sh start_my_server'$/)
            .length.should == 1
      end
    end
  end
end
