require 'spec_helper'

describe Dockly::Docker::Registry do
  subject { described_class.new(:name => :dockly_registry) }

  describe '#authenticate!' do
    context 'when the password has not been supplied via the DSL' do
      subject {
        described_class.new(
          :name => 'no-password',
          :email => 'fake@email.com',
          :username => 'fakeuser'
        )
      }

      before { ::Docker.stub(:authenticate!) }

      it 'prompts the user for the password' do
        subject.should_receive(:get_password)
        expect { subject.authenticate! }.to_not raise_error
      end
    end

    context 'when the password has been supplied via the DSL' do
      subject {
        described_class.new(
          :name => 'no-password',
          :email => 'fake@email.com',
          :password => 'fakepassword',
          :username => 'fakeuser'
        )
      }

      context 'when authentication succeeds' do
        before { ::Docker.stub(:authenticate!) }

        it 'does nothing' do
          subject.should_not_receive(:get_password)
          expect { subject.authenticate! }.to_not raise_error
        end
      end

      context 'when authentication fails' do
        before do
          ::Docker.stub(:authenticate!).and_raise(::Docker::Error::AuthenticationError)
        end

        it 'raieses an error' do
          subject.should_not_receive(:get_password)
          expect { subject.authenticate! }.to raise_error
        end
      end
    end
  end

  describe '#get_password' do
    context 'when STDOUT is not a tty' do
      before { STDIN.stub(:tty?).and_return(false) }

      it 'raises an error' do
        expect { subject.get_password }.to raise_error
      end
    end

    context 'when STDOUT is a tty' do
      let(:password) { '~~my password~~' }

      before do
        STDIN.stub(:tty?).and_return(true)
        STDOUT.stub(:puts)
        STDIN.stub(:gets).and_return(password)
      end

      it 'reads the password from the user' do
        subject.get_password.should == password
      end
    end
  end
end
