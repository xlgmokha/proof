# frozen_string_literal: true

require 'rails_helper'

# RFC 9126: OAuth 2.0 Pushed Authorization Requests
RSpec.describe 'pushed authorization requests' do
  let(:client) { create(:client) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }
  let(:state) { SecureRandom.uuid }
  let(:params) do
    {
      response_type: 'code', redirect_uri: client.redirect_uris[0], state: state, scope: 'admin',
      code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
    }
  end

  def push(positional = {}, headers: self.headers, **extra)
    post '/oauth/par', params: params.merge(positional).merge(extra), headers: headers
  end

  describe 'POST /oauth/par' do
    context 'when the request is valid' do
      before { push }

      # Section 2.2
      specify { expect(response).to have_http_status(:created) }
      specify { expect(response.content_type).to start_with('application/json') }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(json[:request_uri]).to start_with('urn:ietf:params:oauth:request_uri:') }
      specify { expect(json[:expires_in]).to be_between(1, 600) }

      it 'stores the parameters for the client' do
        pushed = PushedAuthorizationRequest.last
        expect(pushed.client).to eql(client)
        expect(pushed.parameters).to include('state' => state, 'code_challenge' => PkceHelpers::PKCE_CHALLENGE)
      end
    end

    context 'when the client is not authenticated' do
      before { push({}, headers: {}) }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(json[:error]).to eql('invalid_client') }
      specify { expect(PushedAuthorizationRequest.count).to be_zero }
    end

    context 'when a public client pushes a request' do
      let(:client) { create(:client, :public) }

      before { push({ client_id: client.to_param }, headers: {}) }

      specify { expect(response).to have_http_status(:created) }
    end

    context 'when client_id is for another client' do
      before { push(client_id: SecureRandom.uuid) }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end

    # Section 2.1
    context 'when the request includes a request_uri' do
      before { push(request_uri: 'urn:ietf:params:oauth:request_uri:abc') }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end

    # Section 2.3: the same validation as the authorization endpoint
    context 'when the redirect_uri is not registered' do
      before { push(redirect_uri: 'https://evil.example.com/cb') }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end

    context 'when the code challenge is missing' do
      before { post '/oauth/par', params: params.except(:code_challenge, :code_challenge_method), headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end

    context 'when the scope is not supported' do
      before { push(scope: 'nope') }

      specify { expect(json[:error]).to eql('invalid_scope') }
    end

    context 'when the response_type is not supported' do
      before { push(response_type: 'token') }

      specify { expect(json[:error]).to eql('unsupported_response_type') }
    end
  end

  describe 'GET /oauth/authorizations with a request_uri' do
    let(:user) { create(:user) }
    let(:request_uri) { json[:request_uri] }

    before do
      http_login(user)
      push
    end

    context 'when the request_uri is valid' do
      before { get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: request_uri } }

      specify { expect(response).to have_http_status(:ok) }

      it 'uses the pushed parameters when the user approves' do
        post '/oauth/authorizations'
        query = Rack::Utils.parse_query(URI.parse(response.location).query)
        expect(query['state']).to eql(state)
        expect(Authorization.last.scope).to eql('admin')
        expect(Authorization.last.challenge).to eql(PkceHelpers::PKCE_CHALLENGE)
      end
    end

    # Section 4: other parameters of the request are ignored.
    context 'when the query carries other parameters' do
      before do
        get '/oauth/authorizations',
          params: { client_id: client.to_param, request_uri: request_uri, scope: 'nope', redirect_uri: 'https://evil.example.com' }
        post '/oauth/authorizations'
      end

      specify { expect(response.location).to start_with(client.redirect_uris[0]) }
      specify { expect(Authorization.last.scope).to eql('admin') }
    end

    context 'when the request_uri is used twice' do
      before do
        get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: request_uri }
        get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: request_uri }
      end

      # Section 4: the reference can be used once.
      specify { expect(Rack::Utils.parse_query(URI.parse(response.location).query)['error']).to eql('invalid_request_uri') }
    end

    context 'when the request_uri has expired' do
      before do
        PushedAuthorizationRequest.update_all(expires_at: 1.second.ago)
        get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: request_uri }
      end

      specify { expect(Rack::Utils.parse_query(URI.parse(response.location).query)['error']).to eql('invalid_request_uri') }
    end

    context 'when the request_uri was pushed by another client' do
      let(:other) { create(:client) }

      before { get '/oauth/authorizations', params: { client_id: other.to_param, request_uri: request_uri } }

      specify { expect(response.location).to start_with(other.redirect_uris[0]) }
      specify { expect(Rack::Utils.parse_query(URI.parse(response.location).query)['error']).to eql('invalid_request_uri') }
    end

    context 'when the request_uri is unknown' do
      before { get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: 'urn:ietf:params:oauth:request_uri:nope', redirect_uri: client.redirect_uris[0], state: state } }

      let(:query) { Rack::Utils.parse_query(URI.parse(response.location).query) }

      # Section 4: invalid_request_uri
      specify { expect(query['error']).to eql('invalid_request_uri') }
      specify { expect(query['state']).to eql(state) }
    end
  end

  describe 'a client that requires pushed requests' do
    let(:client) { create(:client, require_pushed_authorization_requests: true) }
    let(:user) { create(:user) }
    let(:query) { Rack::Utils.parse_query(URI.parse(response.location).query) }

    before { http_login(user) }

    context 'when the request is sent directly' do
      before { get '/oauth/authorizations', params: params.merge(client_id: client.to_param) }

      specify { expect(query['error']).to eql('invalid_request') }
    end

    context 'when the request was pushed' do
      before do
        push
        get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: json[:request_uri] }
      end

      specify { expect(response).to have_http_status(:ok) }
    end
  end

  describe 'the metadata' do
    before { get '/.well-known/oauth-authorization-server' }

    specify { expect(json[:pushed_authorization_request_endpoint]).to eql(oauth_par_url) }
    specify { expect(json[:require_pushed_authorization_requests]).to be(false) }
    specify { expect(json[:request_uri_parameter_supported]).to be(true) }
  end
end
