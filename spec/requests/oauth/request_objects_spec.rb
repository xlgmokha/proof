# frozen_string_literal: true

require 'rails_helper'

# RFC 9101: JWT-Secured Authorization Request
RSpec.describe 'signed authorization requests' do
  let(:signing_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwk) { JWT::JWK.new(signing_key.public_key, kid: 'key-1') }
  let(:client) { create(:client, jwks_uri: nil, jwks: { keys: [jwk.export] }) }
  let(:user) { create(:user) }
  let(:state) { SecureRandom.uuid }
  let(:claims) do
    {
      iss: client.to_param, aud: Oauth::Issuer.identifier, exp: 5.minutes.from_now.to_i,
      response_type: 'code', redirect_uri: client.redirect_uris[0], state: state, scope: 'admin',
      code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
    }
  end
  let(:request_object) { JWT.encode(claims, signing_key, 'RS256', kid: 'key-1', typ: 'oauth-authz-req+jwt') }
  let(:query) { Rack::Utils.parse_query(URI.parse(response.location).query) }

  before { http_login(user) }

  context 'when the request object is valid' do
    before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object } }

    specify { expect(response).to have_http_status(:ok) }

    it 'uses the parameters of the object' do
      post '/oauth/authorizations'
      expect(Rack::Utils.parse_query(URI.parse(response.location).query)['state']).to eql(state)
      expect(Authorization.last.challenge).to eql(PkceHelpers::PKCE_CHALLENGE)
    end
  end

  # Section 6.3: parameters outside of the object are ignored.
  context 'when the query disagrees with the object' do
    before do
      get '/oauth/authorizations', params: {
        client_id: client.to_param, request: request_object,
        redirect_uri: 'https://evil.example.com', response_type: 'token', scope: 'nope'
      }
      post '/oauth/authorizations'
    end

    specify { expect(response.location).to start_with(client.redirect_uris[0]) }
    specify { expect(Authorization.last.scope).to eql('admin') }
  end

  context 'when the object is signed with another key' do
    let(:request_object) { JWT.encode(claims, OpenSSL::PKey::RSA.generate(2048), 'RS256', kid: 'key-1') }

    before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object, redirect_uri: client.redirect_uris[0], state: state } }

    specify { expect(query['error']).to eql('invalid_request_object') }
    specify { expect(query['state']).to eql(state) }
  end

  context 'when the object is not signed' do
    let(:request_object) { JWT.encode(claims, nil, 'none') }

    before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object, redirect_uri: client.redirect_uris[0] } }

    specify { expect(query['error']).to eql('invalid_request_object') }
  end

  context 'when the object is signed with a symmetric key' do
    let(:request_object) { JWT.encode(claims, 'secret', 'HS256') }

    before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object, redirect_uri: client.redirect_uris[0] } }

    specify { expect(query['error']).to eql('invalid_request_object') }
  end

  {
    'iss is not the client' => { iss: SecureRandom.uuid },
    'aud is not this server' => { aud: 'https://evil.example.com' },
    'exp is missing' => { exp: nil },
    'the object has expired' => { exp: 1.hour.ago.to_i },
    'the lifetime is too long' => { exp: 1.week.from_now.to_i },
    'client_id is for another client' => { client_id: SecureRandom.uuid },
    'request_uri is nested' => { request_uri: 'urn:ietf:params:oauth:request_uri:x' },
  }.each do |reason, change|
    context "when #{reason}" do
      let(:claims) { super().merge(change).compact }

      before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object, redirect_uri: client.redirect_uris[0] } }

      specify { expect(query['error']).to eql('invalid_request_object') }
    end
  end

  # RFC 9101 Section 4: the audience is the issuer identifier, not an endpoint URL.
  context 'when the audience is the endpoint url' do
    let(:claims) { super().merge(aud: oauth_authorizations_url) }

    before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object, redirect_uri: client.redirect_uris[0] } }

    specify { expect(query['error']).to eql('invalid_request_object') }
  end

  context 'when request and request_uri are both sent' do
    before do
      get '/oauth/authorizations', params: {
        client_id: client.to_param, request: request_object, request_uri: 'urn:ietf:params:oauth:request_uri:x',
        redirect_uri: client.redirect_uris[0]
      }
    end

    specify { expect(query['error']).to eql('invalid_request') }
  end

  context 'when the object has a request that fails the usual validation' do
    let(:claims) { super().merge(code_challenge_method: 'plain') }

    before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object } }

    specify { expect(query['error']).to eql('invalid_request') }
  end

  context 'when the client requires signed request objects' do
    let(:client) { create(:client, jwks_uri: nil, jwks: { keys: [jwk.export] }, require_signed_request_object: true) }

    context 'without an object' do
      before do
        get '/oauth/authorizations', params: {
          client_id: client.to_param, response_type: 'code', redirect_uri: client.redirect_uris[0],
          code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
        }
      end

      specify { expect(query['error']).to eql('invalid_request') }
    end

    context 'with an object' do
      before { get '/oauth/authorizations', params: { client_id: client.to_param, request: request_object } }

      specify { expect(response).to have_http_status(:ok) }
    end
  end

  context 'when the object is pushed (RFC 9126 with RFC 9101)' do
    let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }

    before do
      post '/oauth/par', params: { request: request_object }, headers: { 'Authorization' => credentials }
      get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: json[:request_uri] }
    end

    specify { expect(response).to have_http_status(:ok) }
  end

  context 'when an invalid object is pushed' do
    let(:request_object) { 'garbage' }
    let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }

    before { post '/oauth/par', params: { request: request_object }, headers: { 'Authorization' => credentials } }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:error]).to eql('invalid_request_object') }
  end

  describe 'the metadata' do
    before { get '/.well-known/oauth-authorization-server' }

    specify { expect(json[:request_parameter_supported]).to be(true) }
    specify { expect(json[:request_object_signing_alg_values_supported]).to include('RS256', 'ES256') }
    specify { expect(json[:request_object_signing_alg_values_supported]).not_to include('none', 'HS256') }
  end
end
