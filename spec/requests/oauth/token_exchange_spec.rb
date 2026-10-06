# frozen_string_literal: true

require 'rails_helper'

# RFC 8693: OAuth 2.0 Token Exchange
RSpec.describe 'token exchange' do
  let(:grant_type) { 'urn:ietf:params:oauth:grant-type:token-exchange' }
  let(:access_type) { 'urn:ietf:params:oauth:token-type:access_token' }
  let(:client) { create(:client, grant_types: GrantTypes::ALL) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }
  let(:user) { create(:user) }
  let(:subject_token) { create(:access_token, audience: client, subject: user, scope: 'admin') }
  let(:params) { { grant_type: grant_type, subject_token: subject_token.to_jwt, subject_token_type: access_type } }

  def exchange(positional = {}, headers: self.headers, **extra)
    @json = nil
    post '/oauth/tokens', params: params.merge(positional).merge(extra), headers: headers
  end

  context 'when exchanging an access token' do
    before { exchange }

    # Section 2.2.1
    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.headers['Cache-Control']).to include('no-store') }
    specify { expect(json[:access_token]).to be_present }
    specify { expect(json[:issued_token_type]).to eql(access_type) }
    specify { expect(json[:token_type]).to eql('Bearer') }
    specify { expect(json[:expires_in]).to be_between(1, 3600) }
    specify { expect(json[:scope]).to eql('admin') }
    specify { expect(json).not_to have_key(:refresh_token) }

    it 'is for the same subject' do
      expect(Token.claims_for(json[:access_token])[:sub]).to eql(user.to_param)
    end

    it 'leaves the subject token usable' do
      expect(subject_token.reload).not_to be_revoked
    end
  end

  context 'when the subject token type is the generic jwt type' do
    before { exchange(subject_token_type: 'urn:ietf:params:oauth:token-type:jwt') }

    specify { expect(response).to have_http_status(:ok) }
  end

  context 'when a narrower scope is requested' do
    let(:subject_token) { create(:access_token, audience: client, subject: user, scope: 'admin') }

    before { exchange(scope: 'admin') }

    specify { expect(json[:scope]).to eql('admin') }
  end

  context 'when a wider scope is requested' do
    let(:subject_token) { create(:access_token, audience: client, subject: user, scope: nil) }

    before { exchange(scope: 'admin') }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:error]).to eql('invalid_scope') }
  end

  context 'when a resource is requested' do
    before { exchange(resource: 'https://api.example.com') }

    specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql('https://api.example.com') }
  end

  context 'when an audience is requested' do
    before { exchange(audience: 'billing-service') }

    specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql('billing-service') }
  end

  context 'when the resource is not a valid URI' do
    before { exchange(resource: 'nope') }

    specify { expect(json[:error]).to eql('invalid_target') }
  end

  context 'when an actor token is given' do
    let(:actor) { create(:user) }
    let(:actor_token) { create(:access_token, audience: client, subject: actor) }

    before { exchange(actor_token: actor_token.to_jwt, actor_token_type: access_type) }

    # Section 4.1: delegation is expressed with the act claim.
    specify { expect(response).to have_http_status(:ok) }
    specify { expect(Token.claims_for(json[:access_token])[:sub]).to eql(user.to_param) }
    specify { expect(Token.claims_for(json[:access_token])[:act]).to eql('sub' => actor.to_param) }

    it 'nests earlier actors' do
      newer = create(:user)
      nested = Token.from_jwt(json[:access_token], token_type: :access)
      post '/oauth/tokens', headers: headers, params: {
        grant_type: grant_type, subject_token: nested.to_jwt, subject_token_type: access_type,
        actor_token: create(:access_token, audience: client, subject: newer).to_jwt, actor_token_type: access_type
      }
      act = Token.claims_for(JSON.parse(response.body)['access_token'])[:act]
      expect(act).to eql('sub' => newer.to_param, 'act' => { 'sub' => actor.to_param })
    end
  end

  context 'when an actor_token_type is given without an actor_token' do
    before { exchange(actor_token_type: access_type) }

    specify { expect(json[:error]).to eql('invalid_request') }
  end

  context 'when the actor token is not valid' do
    before { exchange(actor_token: 'nope', actor_token_type: access_type) }

    specify { expect(json[:error]).to eql('invalid_grant') }
  end

  context 'when the exchanged token would outlive the subject token' do
    let(:subject_token) { create(:access_token, audience: client, subject: user, expired_at: 5.minutes.from_now) }

    before { exchange }

    specify { expect(json[:expires_in]).to be <= 300 }
  end

  context 'when the subject token is a refresh token' do
    let(:subject_token) { create(:refresh_token, audience: client, subject: user) }

    before { exchange(subject_token_type: 'urn:ietf:params:oauth:token-type:refresh_token') }

    specify { expect(response).to have_http_status(:ok) }
  end

  context 'when the token type does not match the token' do
    let(:subject_token) { create(:refresh_token, audience: client, subject: user) }

    before { exchange }

    specify { expect(json[:error]).to eql('invalid_grant') }
  end

  context 'when the subject token was issued to another client' do
    let(:subject_token) { create(:access_token, audience: create(:client), subject: user) }

    before { exchange }

    specify { expect(json[:error]).to eql('invalid_grant') }
  end

  context 'when the subject token is revoked' do
    let(:subject_token) { create(:access_token, :revoked, audience: client, subject: user) }

    before { exchange }

    specify { expect(json[:error]).to eql('invalid_grant') }
  end

  context 'when the subject token is expired' do
    let(:subject_token) { create(:access_token, :expired, audience: client, subject: user) }

    before { exchange }

    specify { expect(json[:error]).to eql('invalid_grant') }
  end

  context 'when the subject token is missing' do
    before { exchange(subject_token: nil) }

    specify { expect(json[:error]).to eql('invalid_request') }
  end

  context 'when the subject token type is missing' do
    before { exchange(subject_token_type: nil) }

    specify { expect(json[:error]).to eql('invalid_request') }
  end

  context 'when the subject token type is not supported' do
    before { exchange(subject_token_type: 'urn:ietf:params:oauth:token-type:saml2') }

    specify { expect(json[:error]).to eql('invalid_request') }
  end

  context 'when a refresh token is requested' do
    before { exchange(requested_token_type: 'urn:ietf:params:oauth:token-type:refresh_token') }

    specify { expect(json[:error]).to eql('invalid_request') }
  end

  context 'when the client may not use the grant' do
    let(:client) { create(:client, grant_types: %w[authorization_code]) }

    before { exchange }

    specify { expect(json[:error]).to eql('unauthorized_client') }
  end

  context 'when the client is not authenticated' do
    before { exchange({}, headers: {}) }

    specify { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when the subject token is revoked after the exchange' do
    it 'revokes the exchanged token with its family' do
      family = SecureRandom.uuid
      refresh = create(:refresh_token, audience: client, subject: user, family_id: family)
      access = create(:access_token, audience: client, subject: user, family_id: family)
      post '/oauth/tokens', headers: headers, params: { grant_type: grant_type, subject_token: access.to_jwt, subject_token_type: access_type }
      exchanged = Token.from_jwt(JSON.parse(response.body)['access_token'], token_type: :access)

      refresh.revoke!

      expect(exchanged.reload).to be_revoked
    end
  end

  describe 'introspection of a delegated token' do
    let(:actor) { create(:user) }

    before do
      exchange(actor_token: create(:access_token, audience: client, subject: actor).to_jwt, actor_token_type: access_type)
      post '/oauth/tokens/introspect', params: { token: JSON.parse(response.body)['access_token'] }, headers: headers
      @json = nil
    end

    specify { expect(json[:active]).to be(true) }
    specify { expect(json[:act]).to eql(sub: actor.to_param) }
  end
end
