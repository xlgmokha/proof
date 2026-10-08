# frozen_string_literal: true

require 'rails_helper'

# RFC 9396: Rich Authorization Requests
RSpec.describe 'authorization details' do
  let(:details) { [{ type: 'payment', actions: %w[initiate status], locations: ['https://pay.example.com'] }] }
  let(:client) { create(:client, authorization_details_types: %w[payment]) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }

  before { allow(AuthorizationDetails).to receive(:supported_types).and_return(%w[payment account]) }

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  describe 'at the authorization endpoint' do
    let(:user) { create(:user) }
    let(:params) do
      {
        client_id: client.to_param, response_type: 'code', redirect_uri: client.redirect_uris[0],
        code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256',
        authorization_details: details.to_json
      }
    end

    before { http_login(user) }

    it 'shows the details to the user and stores them with the grant' do
      get '/oauth/authorizations', params: params
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('initiate')
      post '/oauth/authorizations'
      expect(Authorization.last.authorization_details).to eql(JSON.parse(details.to_json))
    end

    {
      'not JSON' => 'nope',
      'not an array' => '{"type":"payment"}',
      'empty' => '[]',
      'without a type' => '[{"actions":["a"]}]',
      'of an unsupported type' => '[{"type":"unknown"}]',
      'of a type the client did not register' => '[{"type":"account"}]',
      'with locations that are not strings' => '[{"type":"payment","locations":[1]}]',
      'with an identifier that is not a string' => '[{"type":"payment","identifier":1}]'
    }.each do |name, value|
      it "rejects details #{name} (Section 5)" do
        get '/oauth/authorizations', params: params.merge(authorization_details: value)
        expect(query_of(response.location)['error']).to eql('invalid_authorization_details')
      end
    end
  end

  describe 'at the token endpoint' do
    let(:authorization) { create(:authorization, client: client, authorization_details: JSON.parse(details.to_json)) }
    let(:grant) { { grant_type: 'authorization_code', code: authorization.code, code_verifier: PkceHelpers::PKCE_VERIFIER } }

    it 'returns the granted details and puts them in the token (Section 7, 9)' do
      post '/oauth/tokens', params: grant, headers: headers
      expect(json[:authorization_details]).to eql(JSON.parse(details.to_json).map(&:deep_symbolize_keys))
      expect(Token.claims_for(json[:access_token])[:authorization_details]).to eql(JSON.parse(details.to_json))
    end

    it 'refuses a refresh that asks for details that were not granted' do
      post '/oauth/tokens', params: grant, headers: headers
      refresh = json[:refresh_token]
      @json = nil
      narrower = [{ 'type' => 'payment', 'actions' => %w[initiate], 'locations' => ['https://pay.example.com'] }]
      post '/oauth/tokens', params: { grant_type: 'refresh_token', refresh_token: refresh, authorization_details: narrower.to_json }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to eql('invalid_authorization_details')
    end

    it 'allows a refresh to repeat a subset of them' do
      post '/oauth/tokens', params: grant, headers: headers
      refresh = json[:refresh_token]
      post '/oauth/tokens', params: { grant_type: 'refresh_token', refresh_token: refresh, authorization_details: details.to_json }, headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'carries them through a refresh without being asked' do
      post '/oauth/tokens', params: grant, headers: headers
      refresh = json[:refresh_token]
      @json = nil
      post '/oauth/tokens', params: { grant_type: 'refresh_token', refresh_token: refresh }, headers: headers
      expect(json[:authorization_details]).to be_present
    end

    it 'issues them for client credentials' do
      post '/oauth/tokens', params: { grant_type: 'client_credentials', authorization_details: details.to_json }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json[:authorization_details]).to be_present
    end

    it 'rejects details a client may not use' do
      post '/oauth/tokens', params: { grant_type: 'client_credentials', authorization_details: '[{"type":"account"}]' }, headers: headers
      expect(json[:error]).to eql('invalid_authorization_details')
    end
  end

  describe 'introspection' do
    it 'reports them' do
      token = create(:access_token, audience: client, authorization_details: JSON.parse(details.to_json))
      post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers
      expect(json[:authorization_details]).to be_present
    end
  end

  describe 'metadata and registration' do
    it 'advertises the types (Section 10)' do
      get '/.well-known/oauth-authorization-server'
      expect(json[:authorization_details_types_supported]).to match_array(%w[payment account])
    end

    it 'registers the types a client will use' do
      post '/oauth/clients', params: { client_name: 'App', redirect_uris: ['https://a.example.com/cb'], authorization_details_types: %w[payment] }
      expect(json[:authorization_details_types]).to eql(%w[payment])
    end
  end
end
