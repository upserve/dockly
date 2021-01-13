require 'spec_helper'

describe Dockly::Docker::ECR do
  subject do
    described_class.new(name: 'ecr', server_address: registry)
  end

  let(:username) { 'AWS' }
  let(:password) { 'password' }
  let(:registry) { 'accountid.dkr.ecr.region.amazonaws.com' }
  let(:endpoint) { "https://#{registry}" }
  let(:ecr_client) { Aws::ECR::Client.new(stub_responses: true) }

  after do
    Aws.config[:ecr] = { stub_responses: {} }
  end

  describe '#authenticate!' do
    context 'when AWS provides a username and password for ECR' do
      before do
        Aws.config[:ecr] = {
          stub_responses: {
            get_authorization_token: {
              authorization_data: [
                {
                  authorization_token: Base64.encode64("#{username}:#{password}"),
                  proxy_endpoint: endpoint
                }
              ]
            }
          }
        }
      end

      context 'and docker auth succeeds' do
        before do
          allow(::Docker)
            .to receive(:authenticate!)
            .with({
              'serveraddress' => endpoint,
              'username' => username,
              'password' => password
            })
        end

        it 'does not error' do
          expect { subject.authenticate! }.to_not raise_error
        end
      end

      context 'and docker auth raises and error' do
        before do
          allow(::Docker)
            .to receive(:authenticate!)
            .and_raise(::Docker::Error::AuthenticationError)
        end

        it 'raises' do
          expect { subject.authenticate! }.to raise_error
        end
      end
    end
  end

  context 'when it is unable to get auth from AWS' do
    before do
      Aws.config[:ecr] = {
        stub_responses: {
          get_authorization_token: ->(_context) { raise 'Unable to get token' }
        }
      }
    end

    it 'raises' do
      expect(::Docker).not_to receive(:authenticate!)
      expect { subject.authenticate! }.to raise_error
    end
  end
end
