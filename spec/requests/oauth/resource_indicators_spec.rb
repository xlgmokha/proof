# frozen_string_literal: true

require 'rails_helper'

# RFC 8707: Resource Indicators for OAuth 2.0
RSpec.describe 'resource indicators' do
  let(:client) { create(:client, resources: ['https://api.example.com/v1']) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }
  let(:resource) { 'https://api.example.com/v1' }

  describe 'GET /oauth/authorizations' do
    let(:user) { create(:user) }
    let(:params) do
      {
        client_id: client.to_param, response_type: 'code', redirect_uri: client.redirect_uris[0],
        code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
      }
    end

    before { http_login(user) }

    def error_of(location)
      Rack::Utils.parse_query(URI.parse(location).query)['error']
    end

    context 'when the resource is an absolute URI' do
      before { get '/oauth/authorizations', params: params.merge(resource: resource) }

      specify { expect(response).to have_http_status(:ok) }
    end

    context 'when the resource is relative' do
      before { get '/oauth/authorizations', params: params.merge(resource: '/v1') }

      # Section 2: invalid_target
      specify { expect(error_of(response.location)).to eql('invalid_target') }
    end

    context 'when the resource has a fragment' do
      before { get '/oauth/authorizations', params: params.merge(resource: 'https://api.example.com/v1#x') }

      specify { expect(error_of(response.location)).to eql('invalid_target') }
    end

    context 'when several resources are requested' do
      before { get '/oauth/authorizations', params: params.merge(resource: [resource, 'https://other.example.com']) }

      specify { expect(error_of(response.location)).to eql('invalid_target') }
    end

    context 'when the request is approved' do
      before do
        get '/oauth/authorizations', params: params.merge(resource: resource)
        post '/oauth/authorizations'
      end

      specify { expect(Authorization.last.resource).to eql(resource) }
    end
  end

  describe 'POST /oauth/tokens' do
    let(:authorization) { create(:authorization, client: client, resource: resource) }
    let(:grant) { { grant_type: 'authorization_code', code: authorization.code, code_verifier: PkceHelpers::PKCE_VERIFIER } }

    context 'when the authorization was for a resource' do
      before { post '/oauth/tokens', params: grant, headers: headers }

      # RFC 9068 Section 2.2: the audience is the resource.
      specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql(resource) }
      specify { expect(Token.claims_for(json[:refresh_token], token_type: :refresh)[:aud]).to eql(resource) }
    end

    context 'when the token request repeats the resource' do
      before { post '/oauth/tokens', params: grant.merge(resource: resource), headers: headers }

      specify { expect(response).to have_http_status(:ok) }
    end

    context 'when the client is not allowed the resource' do
      let(:client) { create(:client) }

      # RFC 8707 Section 2: invalid_target for a resource the client may not use.
      before { post '/oauth/tokens', params: grant.merge(resource: resource), headers: headers }

      specify { expect(json[:error]).to eql('invalid_target') }
    end

    context 'when the token request names a different resource' do
      before { post '/oauth/tokens', params: grant.merge(resource: 'https://evil.example.com'), headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_target') }
      specify { expect(authorization.reload).not_to be_revoked }
    end

    context 'when the authorization had no resource and the token request names one' do
      let(:authorization) { create(:authorization, client: client) }

      before { post '/oauth/tokens', params: grant.merge(resource: resource), headers: headers }

      specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql(resource) }
    end

    context 'when the resource is not an absolute URI' do
      before { post '/oauth/tokens', params: grant.merge(resource: 'not a uri'), headers: headers }

      specify { expect(json[:error]).to eql('invalid_target') }
    end

    context 'when no resource is involved' do
      let(:authorization) { create(:authorization, client: client) }

      before { post '/oauth/tokens', params: grant, headers: headers }

      specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql(Oauth::Issuer.identifier) }
    end

    context 'when refreshing a token for a resource' do
      let(:refresh_token) { authorization.issue_tokens_to(client).last }
      let(:params) { { grant_type: 'refresh_token', refresh_token: refresh_token.to_jwt } }

      context 'without naming a resource' do
        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql(resource) }
      end

      context 'naming a different resource' do
        before { post '/oauth/tokens', params: params.merge(resource: 'https://evil.example.com'), headers: headers }

        specify { expect(json[:error]).to eql('invalid_target') }
        specify { expect(refresh_token.reload).not_to be_revoked }
      end
    end

    context 'when using client credentials' do
      before { post '/oauth/tokens', params: { grant_type: 'client_credentials', resource: resource }, headers: headers }

      specify { expect(Token.claims_for(json[:access_token])[:aud]).to eql(resource) }
    end
  end
end
