require 'spec_helper'

describe Dockly::Docker::Registry do
  subject { described_class.new(:name => :dockly_registry) }

  describe '#authenticate!' do
    context 'when authentication is not required' do
      before { subject.authentication_required false }

      it 'does nothing' do
        ::Docker.should_not_receive(:authenticate!)
        subject.authenticate!
      end
    end

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
        ENV.should_receive(:[]).and_return('password')
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
          ENV.should_not_receive(:[])
          expect { subject.authenticate! }.to_not raise_error
        end
      end

      context 'when authentication fails' do
        before do
          ::Docker.stub(:authenticate!).and_raise(::Docker::Error::AuthenticationError)
        end

        it 'raieses an error' do
          ENV.should_not_receive(:[])
          expect { subject.authenticate! }.to raise_error
        end
      end
    end
  end
end
