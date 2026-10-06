# frozen_string_literal: true

require 'rails_helper'

# Requirements found by auditing the server against the RFCs.
RSpec.describe 'conformance hardening' do
  let(:json) { JSON.parse(response.body, symbolize_names: true) }

  # RFC 9068 Section 4 and RFC 8707: a resource server only accepts tokens
  # whose audience names it.
  describe 'audience of access tokens' do
    it 'accepts a token for the server' do
      get '/oauth/me', headers: { 'Authorization' => "Bearer #{create(:access_token).to_jwt}" }
      expect(response).to have_http_status(:ok)
    end

    it 'accepts a token for this very resource' do
      token = create(:access_token, resource: "#{Oauth::Issuer.identifier}/oauth/me")
      get '/oauth/me', headers: { 'Authorization' => "Bearer #{token.to_jwt}" }
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a token meant for another resource server' do
      token = create(:access_token, resource: 'https://other.example/')
      get '/oauth/me', headers: { 'Authorization' => "Bearer #{token.to_jwt}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # RFC 7662 Section 2.1
  describe 'introspection by a public client' do
    let(:client) { create(:client, :public) }

    before do
      post '/oauth/tokens/introspect', params: { token: create(:access_token).to_jwt, client_id: client.to_param }
    end

    specify { expect(response).to have_http_status(:unauthorized) }
  end

  # RFC 7591 / RFC 7523 Section 3: open registration cannot enable assertion grants.
  describe 'dynamic registration of assertion grants' do
    [AssertionGrants::JWT_BEARER_GRANT, AssertionGrants::SAML_BEARER_GRANT].each do |grant|
      it "refuses #{grant}" do
        post '/oauth/clients', params: { client_name: 'App', redirect_uris: ['https://a.example.com/cb'], grant_types: [grant] }
        expect(response).to have_http_status(:bad_request)
        expect(json[:error]).to eql('invalid_client_metadata')
      end
    end
  end

  # RFC 7592: the registration access token is not an ordinary access token.
  describe 'registration access token' do
    let(:registered) do
      post '/oauth/clients', params: { client_name: 'App', redirect_uris: ['https://a.example.com/cb'], grant_types: %w[authorization_code client_credentials] }
      JSON.parse(response.body, symbolize_names: true)
    end

    it 'is not revoked when the client obtains another token' do
      client = Client.find(registered[:client_id])
      client.access_token
      get "/oauth/clients/#{client.to_param}", headers: { 'Authorization' => "Bearer #{registered[:registration_access_token]}" }
      expect(response).to have_http_status(:ok)
    end

    it 'cannot be replaced by a plain client token' do
      client = Client.find(registered[:client_id])
      get "/oauth/clients/#{client.to_param}", headers: { 'Authorization' => "Bearer #{client.access_token.to_jwt}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'a client that uses no redirect flow' do
    it 'does not need redirect_uris' do
      post '/oauth/clients', params: { client_name: 'App', grant_types: %w[client_credentials] }
      expect(response).to have_http_status(:created)
      expect(json[:response_types]).to be_empty
    end
  end

  describe 'metadata' do
    before { get '/.well-known/oauth-authorization-server' }

    specify { expect(json[:revocation_endpoint_auth_signing_alg_values_supported]).to eql(JwtBearerAssertion::ALGORITHMS) }
    specify { expect(json[:introspection_endpoint_auth_signing_alg_values_supported]).to eql(JwtBearerAssertion::ALGORITHMS) }
    specify { expect(json[:revocation_endpoint_auth_methods_supported]).to include('none') }
    specify { expect(json[:introspection_endpoint_auth_methods_supported]).not_to include('none') }
  end
end
