# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JwksFetcher do
  include WebMock::API

  subject { described_class.new(cache: ActiveSupport::Cache::NullStore.new) }

  before { WebMock.enable! }

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  describe '#fetch' do
    context 'when the uri is not https' do
      specify { expect { subject.fetch('http://example.com/jwks') }.to raise_error(described_class::Error, /https/) }
    end

    context 'when the host resolves to a private address' do
      %w[127.0.0.1 10.0.0.5 192.168.1.1 172.16.0.1 169.254.169.254 ::1 ::ffff:127.0.0.1 ::ffff:169.254.169.254 100.64.0.1 64:ff9b::7f00:1 2002:7f00:1:: 224.0.0.1 198.18.0.1].each do |address|
        it "refuses #{address}" do
          allow(Resolv).to receive(:getaddresses).and_return([address])
          expect { subject.fetch('https://internal.example.com/jwks') }.to raise_error(described_class::Error, /private/)
        end
      end
    end

    context 'when the host cannot be resolved' do
      before { allow(Resolv).to receive(:getaddresses).and_return([]) }

      specify { expect { subject.fetch('https://nowhere.example.com/jwks') }.to raise_error(described_class::Error, /resolve/) }
    end

    context 'when the host is public' do
      let(:keys) { { 'keys' => [{ 'kty' => 'RSA', 'n' => 'abc', 'e' => 'AQAB' }] } }

      before do
        allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])
        stub_request(:get, 'https://example.com/jwks').to_return(status: 200, body: keys.to_json)
      end

      specify { expect(subject.fetch('https://example.com/jwks')).to eql(keys) }
    end

    context 'when the server responds with an error' do
      before do
        allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])
        stub_request(:get, 'https://example.com/jwks').to_return(status: 500)
      end

      specify { expect { subject.fetch('https://example.com/jwks') }.to raise_error(described_class::Error) }
    end

    context 'when the response is not json' do
      before do
        allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])
        stub_request(:get, 'https://example.com/jwks').to_return(status: 200, body: 'nope')
      end

      specify { expect { subject.fetch('https://example.com/jwks') }.to raise_error(described_class::Error) }
    end
  end
end
