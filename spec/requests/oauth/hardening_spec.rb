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

  # RFC 6749 Section 3.2 and Appendix B
  describe 'token endpoint parameters' do
    let(:client) { create(:client) }
    let(:auth) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) } }

    it 'accepts a form-urlencoded body' do
      post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: auth
      expect(response).to have_http_status(:ok)
    end

    it 'rejects parameters in the query string' do
      post '/oauth/tokens?grant_type=client_credentials', headers: auth
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to eql('invalid_request')
    end

    it 'rejects a repeated parameter' do
      post '/oauth/tokens', params: 'grant_type=bogus&grant_type=client_credentials', headers: auth.merge('Content-Type' => 'application/x-www-form-urlencoded')
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to eql('invalid_request')
    end

    it 'rejects a JSON body' do
      post '/oauth/tokens', params: { grant_type: 'client_credentials' }.to_json, headers: auth.merge('Content-Type' => 'application/json')
      expect(response).to have_http_status(:bad_request)
    end
  end

  # RFC 8414 Section 3
  describe 'metadata location' do
    it 'is served at the issuer-derived path' do
      get '/.well-known/oauth-authorization-server'
      expect(response).to have_http_status(:ok)
    end

    it 'is not served for another path' do
      get '/.well-known/oauth-authorization-server/tenant'
      expect(response).to have_http_status(:not_found)
    end

    it 'validates the issuer' do
      expect(Oauth::Issuer.valid?('https://a.example/t')).to be(true)
      expect(Oauth::Issuer.valid?('https://a.example/?x=1')).to be(false)
      expect(Oauth::Issuer.valid?('https://a.example/#f')).to be(false)
      expect(Oauth::Issuer.valid?('ftp://a.example')).to be(false)
      expect(Oauth::Issuer.valid?(nil)).to be(false)
    end
  end

  # RFC 6749 Section 5.2: faults of the server are not client errors.
  describe 'an unexpected failure at the token endpoint' do
    let(:client) { create(:client) }

    it 'is a server_error' do
      allow_any_instance_of(Client).to receive(:access_token).and_raise(RuntimeError, 'boom')
      post '/oauth/tokens', params: { grant_type: 'client_credentials' },
        headers: { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
      expect(response).to have_http_status(:internal_server_error)
      expect(json[:error]).to eql('server_error')
    end
  end

  # RFC 9449 Section 4.3: htu is compared after normalisation.
  describe 'DPoP htu normalisation' do
    it 'ignores default ports and case' do
      proof = DpopProof.allocate
      expect(proof.send(:normalize, 'HTTPS://Example.com:443/a/b?x=1')).to eql(proof.send(:normalize, 'https://example.com/a/b'))
    end
  end
end
