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

  # RFC 9700 Section 2.1, RFC 8252 Section 7.3
  describe 'redirect uri schemes' do
    specify { expect(build(:client, redirect_uris: ['http://app.example.com/cb'])).to be_invalid }
    specify { expect(build(:client, redirect_uris: ['http://127.0.0.1/cb'])).to be_valid }
    specify { expect(build(:client, redirect_uris: ['http://[::1]/cb'])).to be_valid }
    specify { expect(build(:client, redirect_uris: ['https://app.example.com/cb'])).to be_valid }
  end

  # RFC 6750 Section 3.1
  describe 'a malformed bearer credential' do
    it 'is an invalid_request' do
      get '/oauth/me', headers: { 'Authorization' => 'Bearer a b' }
      expect(response).to have_http_status(:bad_request)
      expect(response.headers['WWW-Authenticate']).to include('error="invalid_request"')
    end

    it 'is not confused with an absent credential' do
      get '/oauth/me'
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).not_to include('error=')
    end
  end

  # RFC 7009 Section 2.1: the token must have been issued to the client.
  describe 'revoking a token of another client' do
    it 'is refused and the token stays' do
      mine = create(:client)
      token = create(:access_token, audience: create(:client))
      headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(mine.to_param, mine.password) }
      post '/oauth/tokens/revoke', params: { token: token.to_jwt }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(token.reload).not_to be_revoked
    end
  end
end

# RFC 9701: JWT response for token introspection
RSpec.describe 'JWT introspection responses' do
  let(:client) { create(:client) }
  let(:headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) } }
  let(:media_type) { 'application/token-introspection+jwt' }

  def decoded(body)
    JWT.decode(body, Rails.application.config.x.jwt.private_key.public_key, true, algorithm: 'RS256', aud: client.to_param, verify_aud: true)
  end

  it 'signs the response when it is asked for' do
    token = create(:access_token, audience: client)
    post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers.merge('Accept' => media_type)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eql(media_type)
    claims, header = decoded(response.body)
    expect(header['typ']).to eql('token-introspection+jwt')
    expect(claims['iss']).to eql(Oauth::Issuer.identifier)
    expect(claims['iat']).to be_present
    expect(claims['token_introspection']).to include('active' => true, 'client_id' => client.to_param)
  end

  it 'signs an inactive response too' do
    post '/oauth/tokens/introspect', params: { token: 'nope' }, headers: headers.merge('Accept' => media_type)
    expect(decoded(response.body).first['token_introspection']).to eql('active' => false)
  end

  it 'answers with plain JSON otherwise' do
    post '/oauth/tokens/introspect', params: { token: 'nope' }, headers: headers
    expect(response.media_type).to eql('application/json')
  end

  it 'is advertised in the metadata' do
    get '/.well-known/oauth-authorization-server'
    expect(JSON.parse(response.body)['introspection_signing_alg_values_supported']).to eql(%w[RS256])
  end
end

# Findings of the audit against the OAuth 2.1 draft, RFC 9470, RFC 9728 and RFC 7523bis
RSpec.describe 'conformance audit' do
  let(:json) { JSON.parse(response.body, symbolize_names: true) }
  let(:client) { create(:client) }
  let(:user) { create(:user) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }

  describe 'which tokens a resource serves' do
    it 'does not serve SCIM to a registration access token' do
      post '/oauth/clients', params: { client_name: 'App', redirect_uris: ['https://a.example.com/cb'] }
      get '/scim/v2/Users', headers: { 'Authorization' => "Bearer #{json[:registration_access_token]}", 'Accept' => 'application/scim+json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not serve SCIM to a client credentials token' do
      get '/scim/v2/Users', headers: { 'Authorization' => "Bearer #{client.access_token.to_jwt}", 'Accept' => 'application/scim+json' }
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to include('invalid_token')
    end

    it 'does not serve /oauth/me to a token for the SCIM resource' do
      token = create(:access_token, resource: "#{Oauth::Issuer.identifier}/scim/v2")
      get '/oauth/me', headers: { 'Authorization' => "Bearer #{token.to_jwt}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'serves SCIM to a user token for the SCIM resource' do
      token = create(:access_token, resource: "#{Oauth::Issuer.identifier}/scim/v2")
      get '/scim/v2/Users', headers: { 'Authorization' => "Bearer #{token.to_jwt}", 'Accept' => 'application/scim+json' }
      expect(response).to have_http_status(:ok)
    end
  end

  # OAuth 2.1 "Reuse of Authorization Codes"
  describe 'a replayed authorization code' do
    let(:authorization) { create(:authorization, client: client) }
    let(:grant) { { grant_type: 'authorization_code', code: authorization.code, code_verifier: PkceHelpers::PKCE_VERIFIER } }
    let(:headers) { { 'Authorization' => credentials } }

    it 'revokes what was issued when the replay is genuine' do
      post '/oauth/tokens', params: grant, headers: headers
      access = json[:access_token]
      post '/oauth/tokens', params: grant, headers: headers
      expect(Token.authenticate(access)).to be_nil
    end

    it 'does not revoke anything when the replay has the wrong verifier' do
      post '/oauth/tokens', params: grant, headers: headers
      access = json[:access_token]
      post '/oauth/tokens', params: grant.merge(code_verifier: 'x' * 50), headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(Token.authenticate(access)).to be_present
    end
  end

  describe 'authorization request parameters' do
    let(:params) do
      {
        client_id: client.to_param, response_type: 'code', redirect_uri: client.redirect_uris[0],
        code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
      }
    end

    before { http_login(user) }

    it 'treats an empty value as omitted (Section 3.1)' do
      get '/oauth/authorizations', params: params.merge(max_age: '', dpop_jkt: '')
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a repeated parameter' do
      get "/oauth/authorizations?#{params.to_query}&scope=admin"
      expect(response).to have_http_status(:ok)
      get "/oauth/authorizations?#{params.to_query}&state=a&state=b"
      expect(response).to have_http_status(:bad_request)
    end

    it 'shows the scope and the lifetime on the consent page' do
      get '/oauth/authorizations', params: params.merge(scope: 'admin')
      expect(response.body).to include('admin')
      expect(response.body).to include('60 minutes')
    end

    it 'answers unauthorized_client for a client that cannot use the code grant' do
      only_credentials = create(:client, grant_types: %w[client_credentials], response_types: [])
      get '/oauth/authorizations', params: params.merge(client_id: only_credentials.to_param, redirect_uri: only_credentials.redirect_uris[0])
      expect(Rack::Utils.parse_query(URI.parse(response.location).query)['error']).to eql('unauthorized_client')
    end
  end

  describe 'error descriptions' do
    it 'only use the characters the RFC allows' do
      error = GrantError.new('invalid_request', "bad \"quote\" and \\ and \n and é")
      expect(error.description).to match(/\A[\x20\x21\x23-\x5B\x5D-\x7E]*\z/)
    end
  end

  # RFC 9728 Section 3.1 with an issuer that has a path
  describe 'protected resource metadata for an issuer with a path' do
    before { allow(Oauth::Issuer).to receive(:identifier).and_return('http://www.example.com/t1') }

    it 'is found with the issuer path after the well-known segment' do
      get '/.well-known/oauth-protected-resource/t1/oauth/me'
      expect(response).to have_http_status(:ok)
      expect(json[:resource]).to eql('http://www.example.com/t1/oauth/me')
    end

    it 'is not found without the issuer path' do
      get '/.well-known/oauth-protected-resource/oauth/me'
      expect(response).to have_http_status(:not_found)
    end

    it 'is what the challenge points at' do
      get '/oauth/me'
      expect(response.headers['WWW-Authenticate']).to include('resource_metadata="http://www.example.com/.well-known/oauth-protected-resource/t1/oauth/me"')
    end
  end
end

# Findings of the comparison with independent reference implementations
RSpec.describe 'reference comparison' do
  let(:json) { JSON.parse(response.body, symbolize_names: true) }
  let(:client) { create(:client, grant_types: GrantTypes::ALL - [AssertionGrants::SAML_BEARER_GRANT], resources: ['https://api.example.com/v1']) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }

  describe 'registration (RFC 7591, 7592)' do
    def register(extra = {})
      post '/oauth/clients', params: { client_name: 'App', redirect_uris: ['https://a.example.com/cb'] }.merge(extra), as: :json
    end

    it 'issues a registration token that outlives a day' do
      register
      claims = Token.claims_for(json[:registration_access_token])
      expect(claims[:exp]).to be > 1.year.from_now.to_i
    end

    it 'accepts private-use scheme redirect URIs (RFC 8252 Section 7.1)' do
      register(redirect_uris: ['com.example.app:/oauth2redirect'])
      expect(response).to have_http_status(:created)
    end

    it 'refuses schemes that could run code' do
      register(redirect_uris: ['javascript:alert(1)'])
      expect(response).to have_http_status(:bad_request)
    end

    {
      'a scalar grant_types' => { grant_types: 'authorization_code' },
      'a number for client_name' => { client_name: 5 },
      'a string for jwks' => { jwks: 'abc' },
      'non strings in redirect_uris' => { redirect_uris: [1] }
    }.each do |name, extra|
      it "refuses #{name}" do
        register(extra)
        expect(response).to have_http_status(:bad_request)
        expect(json[:error]).to eql('invalid_client_metadata')
      end
    end

    it 'gives a secret to a public client that becomes confidential' do
      register(token_endpoint_auth_method: 'none')
      token = json[:registration_access_token]
      id = json[:client_id]
      @json = nil
      put "/oauth/clients/#{id}", params: { client_id: id, client_name: 'App', redirect_uris: ['https://a.example.com/cb'], token_endpoint_auth_method: 'client_secret_basic' },
        headers: { 'Authorization' => "Bearer #{token}" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['client_secret']).to be_present
    end

    it 'challenges when the client does not exist' do
      register
      token = json[:registration_access_token]
      get "/oauth/clients/#{SecureRandom.uuid}", headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to include('invalid_token')
    end

    it 'does not revoke an unrelated token for an unknown client' do
      user_token = create(:access_token)
      get "/oauth/clients/#{SecureRandom.uuid}", headers: { 'Authorization' => "Bearer #{user_token.to_jwt}" }
      expect(user_token.reload).not_to be_revoked
    end
  end

  describe 'the jwt bearer grant without an assertion' do
    it 'is an invalid_request' do
      post '/oauth/tokens', params: { grant_type: AssertionGrants::JWT_BEARER_GRANT }, headers: headers
      expect(json[:error]).to eql('invalid_request')
    end
  end

  describe 'repeated resource parameters (RFC 8707)' do
    it 'are an invalid_target, not an invalid_request' do
      post '/oauth/tokens', params: 'grant_type=client_credentials&resource=https://api.example.com/v1&resource=https://b.example.com',
        headers: headers.merge('Content-Type' => 'application/x-www-form-urlencoded')
      expect(json[:error]).to eql('invalid_target')
    end
  end

  describe 'the device authorization endpoint with a resource' do
    it 'carries the resource to the request' do
      post '/oauth/device_authorization', params: { resource: 'https://api.example.com/v1' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(DeviceAuthorization.last.resource).to eql('https://api.example.com/v1')
    end

    it 'refuses a resource the client may not use' do
      post '/oauth/device_authorization', params: { resource: 'https://evil.example.com' }, headers: headers
      expect(json[:error]).to eql('invalid_target')
    end
  end
end

