# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Token, type: :model do
  describe "revoke!" do
    subject { create(:access_token) }

    context "when the token has not been revoked yet" do
      before do
        freeze_time
        subject.revoke!
      end

      specify { expect(subject.reload.revoked_at.to_i).to eql(Time.current.to_i) }
    end

    # RFC 7009 Section 2.1: revoking a refresh token also revokes the access
    # tokens issued from the same grant.
    context "when a refresh token is revoked" do
      subject { create(:refresh_token, family_id: family) }

      let(:family) { SecureRandom.uuid }
      let!(:access_token) { create(:access_token, family_id: family) }
      let!(:unrelated) { create(:access_token) }

      before { subject.revoke! }

      specify { expect(access_token.reload).to be_revoked }
      specify { expect(unrelated.reload).not_to be_revoked }
    end

    context "when an access token is revoked" do
      subject { create(:access_token, family_id: family) }

      let(:family) { SecureRandom.uuid }
      let!(:refresh_token) { create(:refresh_token, family_id: family) }

      before { subject.revoke! }

      specify { expect(subject.reload).to be_revoked }
      specify { expect(refresh_token.reload).not_to be_revoked }
    end

    context "when the token was already revoked" do
      subject { create(:access_token, revoked_at: 1.hour.ago) }

      specify { expect { subject.revoke! }.not_to(change { subject.reload.revoked_at }) }
    end
  end

  describe "#to_jwt" do
    let(:token) { create(:access_token, scope: 'admin', resource: 'https://api.example.com') }
    let(:payload) { JWT.decode(token.to_jwt, nil, false) }
    let(:claims) { payload[0] }
    let(:header) { payload[1] }

    # RFC 9068 Section 2
    specify { expect(header['typ']).to eql('at+jwt') }
    specify { expect(header['alg']).to eql('RS256') }
    specify { expect(claims).to include('iss' => Oauth::Issuer.identifier, 'sub' => token.subject.to_param, 'jti' => token.id) }
    specify { expect(claims['client_id']).to eql(token.audience.to_param) }
    specify { expect(claims['aud']).to eql('https://api.example.com') }
    specify { expect(claims['scope']).to eql('admin') }
    specify { expect(claims).to include('exp', 'iat') }
    specify { expect(JWT.decode(create(:refresh_token).to_jwt, nil, false)[1]['typ']).to eql('rt+jwt') }
    specify { expect(claims).not_to include('cnf') }

    context 'when the token is bound to a DPoP key' do
      let(:token) { create(:access_token, dpop_jkt: 'thumbprint') }

      specify { expect(claims['cnf']).to eql('jkt' => 'thumbprint') }
    end
  end

  describe ".claims_for with the wrong kind of token" do
    let(:access_token) { create(:access_token).to_jwt }
    let(:refresh_token) { create(:refresh_token).to_jwt }

    specify { expect(described_class.claims_for(access_token, token_type: :refresh)).to be_empty }
    specify { expect(described_class.claims_for(refresh_token, token_type: :access)).to be_empty }

    it 'rejects a JWT without the at+jwt type' do
      jwt = BearerToken.new.encode(create(:access_token).claims)
      expect(described_class.claims_for(jwt)).to be_empty
    end

    it 'rejects a JWT from another issuer' do
      jwt = BearerToken.new.encode(create(:access_token).claims(iss: 'https://evil.example.com'), typ: 'at+jwt')
      expect(described_class.claims_for(jwt)).to be_empty
    end
  end

  describe ".expired" do
    let!(:active_token) { create(:access_token) }
    let!(:expired_token) { create(:access_token, expired_at: 1.second.ago) }

    specify { expect(described_class.expired).to match_array([expired_token]) }
  end

  describe ".revoked" do
    let!(:revoked_token) { create(:access_token, revoked_at: 1.second.ago) }
    let!(:active_token) { create(:access_token) }

    specify { expect(described_class.revoked).to match_array([revoked_token]) }
  end

  describe ".claims_for" do
    subject { described_class }

    let(:access_token) { build_stubbed(:access_token).to_jwt }
    let(:refresh_token) { build_stubbed(:refresh_token).to_jwt }

    specify { expect(subject.claims_for('blah', token_type: :access)).to be_empty }
    specify { expect(subject.claims_for('blah', token_type: :refresh)).to be_empty }
    specify { expect(subject.claims_for(access_token, token_type: :access)).to be_present }
    specify { expect(subject.claims_for(refresh_token, token_type: :refresh)).to be_present }
  end

  describe ".authenticate" do
    subject { described_class }

    context "when the access_token is active" do
      let(:token) { create(:access_token) }

      specify { expect(subject.authenticate(token.to_jwt)).to eql(token) }
    end

    context "when the token is a refresh token" do
      let(:token) { create(:refresh_token) }

      specify { expect(subject.authenticate(token.to_jwt)).to be_nil }
    end

    context "when the access token has been revoked" do
      let(:token) { create(:access_token, :revoked) }

      specify { expect(subject.authenticate(token.to_jwt)).to be_nil }
    end

    context "when the access token is expired" do
      let(:token) { create(:access_token, :expired) }

      specify { expect(subject.authenticate(token.to_jwt)).to be_nil }
    end
  end
end
