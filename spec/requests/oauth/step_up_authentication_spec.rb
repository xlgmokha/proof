# frozen_string_literal: true

require 'rails_helper'

# RFC 9470: OAuth 2.0 Step Up Authentication Challenge Protocol
RSpec.describe 'step up authentication' do
  let(:client) { create(:client) }
  let(:user) { create(:user) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:params) do
    {
      client_id: client.to_param, response_type: 'code', redirect_uri: client.redirect_uris[0],
      code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
    }
  end
  let(:query) { Rack::Utils.parse_query(URI.parse(response.location).query) }

  before { http_login(user) }

  describe 'acr_values at the authorization endpoint (Section 4)' do
    it 'proceeds when the login meets the class' do
      get '/oauth/authorizations', params: params.merge(acr_values: AuthenticationContext::PASSWORD)
      expect(response).to have_http_status(:ok)
    end

    it 'proceeds when one of the classes is met' do
      get '/oauth/authorizations', params: params.merge(acr_values: "unknown #{AuthenticationContext::PASSWORD}")
      expect(response).to have_http_status(:ok)
    end

    it 'fails with unmet_authentication_requirements when it cannot be met (Section 5)' do
      get '/oauth/authorizations', params: params.merge(acr_values: AuthenticationContext::MFA)
      expect(query['error']).to eql('unmet_authentication_requirements')
    end

    it 'fails for a class that is not known' do
      get '/oauth/authorizations', params: params.merge(acr_values: 'myACR')
      expect(query['error']).to eql('unmet_authentication_requirements')
    end
  end

  describe 'max_age at the authorization endpoint' do
    it 'proceeds when the login is recent enough' do
      get '/oauth/authorizations', params: params.merge(max_age: '3600')
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a value that is not a number' do
      get '/oauth/authorizations', params: params.merge(max_age: 'soon')
      expect(query['error']).to eql('invalid_request')
    end

    context 'when the login is too old' do
      before { UserSession.update_all(created_at: 10.minutes.ago) }

      it 'asks the user to sign in again and comes back to the request' do
        get '/oauth/authorizations', params: params.merge(max_age: '60')
        expect(response).to redirect_to('/session/new')

        http_login(user)
        get '/response'
        expect(response.location).to include('/oauth/authorizations')

        get response.location
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'the authentication event in tokens (Section 6, RFC 9068 Section 2.2.1)' do
    let(:grant) { { grant_type: 'authorization_code', code: Authorization.last.code, code_verifier: PkceHelpers::PKCE_VERIFIER, redirect_uri: client.redirect_uris[0] } }

    before do
      get '/oauth/authorizations', params: params
      post '/oauth/authorizations'
      post '/oauth/tokens', params: grant, headers: { 'Authorization' => credentials }
    end

    it 'puts acr and auth_time in the access token' do
      claims = Token.claims_for(json[:access_token])
      expect(claims[:acr]).to eql(AuthenticationContext::PASSWORD)
      expect(claims[:auth_time]).to eql(UserSession.last.created_at.to_i)
    end

    it 'keeps them when the token is refreshed' do
      refresh = json[:refresh_token]
      @json = nil
      post '/oauth/tokens', params: { grant_type: 'refresh_token', refresh_token: refresh }, headers: { 'Authorization' => credentials }
      expect(Token.claims_for(json[:access_token])[:acr]).to eql(AuthenticationContext::PASSWORD)
    end

    it 'reports them when introspected' do
      access = json[:access_token]
      @json = nil
      post '/oauth/tokens/introspect', params: { token: access }, headers: { 'Authorization' => credentials }
      expect(json[:acr]).to eql(AuthenticationContext::PASSWORD)
      expect(json[:auth_time]).to be_present
    end
  end

  describe 'metadata (Section 7)' do
    before { get '/.well-known/oauth-authorization-server' }

    specify { expect(json[:acr_values_supported]).to match_array(AuthenticationContext::SUPPORTED) }
  end
end

# A resource that needs a recent or a strong authentication (Section 3).
RSpec.describe 'the step up challenge of a resource', type: :controller do
  controller(ActionController::API) do
    include BearerAuthentication

    def index
      authenticate_bearer!(acr_values: [AuthenticationContext::MFA], max_age: 300)
      head :ok unless performed?
    end
  end

  before { routes.draw { get 'index' => 'anonymous#index' } }

  def call(token)
    request.headers['Authorization'] = "Bearer #{token.to_jwt}"
    get :index
  end

  it 'accepts a token of a strong enough, recent authentication' do
    call(create(:access_token, acr: AuthenticationContext::MFA, auth_time: 1.minute.ago.to_i))
    expect(response).to have_http_status(:ok)
  end

  it 'asks for another class of authentication' do
    call(create(:access_token, acr: AuthenticationContext::PASSWORD, auth_time: 1.minute.ago.to_i))
    expect(response).to have_http_status(:unauthorized)
    header = response.headers['WWW-Authenticate']
    expect(header).to include('error="insufficient_user_authentication"')
    expect(header).to include(%(acr_values="#{AuthenticationContext::MFA}"))
    expect(header).to include('max_age="300"')
  end

  it 'asks for a more recent authentication' do
    call(create(:access_token, acr: AuthenticationContext::MFA, auth_time: 1.hour.ago.to_i))
    expect(response.headers['WWW-Authenticate']).to include('insufficient_user_authentication')
  end

  it 'asks when the token has no record of the authentication' do
    call(create(:access_token))
    expect(response.headers['WWW-Authenticate']).to include('insufficient_user_authentication')
  end
end
