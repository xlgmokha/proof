# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Client do
  describe '#jwks' do
    let(:public_key) { JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048).public_key).export }

    specify { expect(build(:client, jwks_uri: nil, jwks: { keys: [public_key] })).to be_valid }
    specify { expect(build(:client, jwks_uri: nil, jwks: { 'nope' => [] })).to be_invalid }
    specify { expect(build(:client, jwks_uri: nil, jwks: { 'keys' => ['nope'] })).to be_invalid }
    specify { expect(build(:client, jwks_uri: 'https://example.com/jwks', jwks: { keys: [public_key] })).to be_invalid }

    it 'rejects private key material' do
      private_key = JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048)).export(include_private: true)
      expect(build(:client, jwks_uri: nil, jwks: { keys: [private_key] })).to be_invalid
    end
  end

  describe "#validation" do
    specify { expect(build(:client)).to be_valid }
    specify { expect(build(:client, redirect_uris: nil)).to be_invalid }
    specify { expect(build(:client, redirect_uris: [])).to be_invalid }
    specify { expect(build(:client, redirect_uris: ['<script>alert("hi")</script>'])).to be_invalid }
    specify { expect(build(:client, redirect_uris: ['invalid'])).to be_invalid }
    specify { expect(build(:client, redirect_uris: 'invalid')).to be_invalid }
    specify { expect(build(:client, name: nil)).to be_invalid }
  end

  describe "#redirect_url" do
    subject { build(:client) }

    let(:code) { SecureRandom.uuid }
    let(:redirect_uri) { subject.redirect_uris[0] }

    # RFC 6749 Section 4.1.2: the response is in the query component.
    specify { expect(subject.redirect_url(code: code)).to eql("#{redirect_uri}?code=#{code}") }
    specify { expect(subject.redirect_url(code: code, empty: nil)).to eql("#{redirect_uri}?code=#{code}") }
    specify { expect(subject.redirect_url(state: '<a b>')).to eql("#{redirect_uri}?state=%3Ca+b%3E") }
    specify { expect(subject.redirect_url(code: code, to: 'https://evil.example.com')).to be_nil }

    context 'when the redirect uri already has a query' do
      subject { build(:client, redirect_uris: ['https://example.com/cb?a=1']) }

      specify { expect(subject.redirect_url(code: code)).to eql("https://example.com/cb?a=1&code=#{code}") }
    end
  end

  describe '#resolve_redirect_uri' do
    subject { build(:client, redirect_uris: ['https://a.example.com/cb', 'http://127.0.0.1/cb', 'http://[::1]/cb']) }

    specify { expect(subject.resolve_redirect_uri('https://a.example.com/cb')).to eql('https://a.example.com/cb') }
    specify { expect(subject.resolve_redirect_uri('https://a.example.com/cb2')).to be_nil }
    specify { expect(subject.resolve_redirect_uri('https://a.example.com:8443/cb')).to be_nil }
    specify { expect(subject.resolve_redirect_uri(nil)).to be_nil }
    specify { expect(subject.resolve_redirect_uri('http://127.0.0.1:5000/cb')).to eql('http://127.0.0.1:5000/cb') }
    specify { expect(subject.resolve_redirect_uri('http://[::1]:5000/cb')).to eql('http://[::1]:5000/cb') }
    specify { expect(subject.resolve_redirect_uri('http://127.0.0.1:5000/other')).to be_nil }
    specify { expect(subject.resolve_redirect_uri('http://localhost:5000/cb')).to be_nil }
    specify { expect(subject.resolve_redirect_uri('https://a.example.com:8443/cb')).to be_nil }
    specify { expect(build(:client, redirect_uris: ['https://a.example.com/cb']).resolve_redirect_uri(nil)).to eql('https://a.example.com/cb') }
  end

  describe 'redirect uri validation' do
    specify { expect(build(:client, redirect_uris: ['https://example.com/cb#fragment'])).to be_invalid }
  end
end
