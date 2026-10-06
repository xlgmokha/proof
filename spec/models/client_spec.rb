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

    specify { expect(subject.redirect_url(code: code)).to eql("#{redirect_uri}#code=#{code}") }
    specify { expect { subject.redirect_url(state: '<script>alert("hi");</script>') }.to raise_error(URI::InvalidURIError) }
  end
end
