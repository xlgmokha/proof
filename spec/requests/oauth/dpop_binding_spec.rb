# frozen_string_literal: true

require 'rails_helper'

# RFC 9449 Section 8 (nonces) and Section 10 (authorization code binding)
RSpec.describe 'DPoP code binding and nonces' do
  let(:client) { create(:client) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:token_url) { 'http://www.example.com/oauth/tokens' }
  let(:grant) { { grant_type: 'authorization_code', code: authorization.code, code_verifier: PkceHelpers::PKCE_VERIFIER } }

  def exchange(proof)
    headers = { 'Authorization' => credentials }
    headers['DPoP'] = proof if proof
    post '/oauth/tokens', params: grant, headers: headers
  end

  describe 'a code bound to a key' do
    let(:authorization) { create(:authorization, client: client, dpop_jkt: dpop_thumbprint) }

    it 'is redeemed with a proof from that key' do
      exchange(dpop_proof(url: token_url))
      expect(response).to have_http_status(:ok)
      expect(json[:token_type]).to eql('DPoP')
    end

    it 'is refused with another key' do
      exchange(dpop_proof(url: token_url, key: OpenSSL::PKey::EC.generate('prime256v1')))
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to eql('invalid_dpop_proof')
    end

    it 'is refused without a proof' do
      exchange(nil)
      expect(json[:error]).to eql('invalid_dpop_proof')
    end
  end

  describe 'dpop_jkt at the authorization endpoint' do
    let(:user) { create(:user) }
    let(:params) do
      {
        client_id: client.to_param, response_type: 'code', redirect_uri: client.redirect_uris[0],
        code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
      }
    end

    before { http_login(user) }

    it 'binds the issued code to the thumbprint' do
      get '/oauth/authorizations', params: params.merge(dpop_jkt: dpop_thumbprint)
      post '/oauth/authorizations'
      expect(Authorization.last.dpop_jkt).to eql(dpop_thumbprint)
    end

    it 'rejects a malformed thumbprint' do
      get '/oauth/authorizations', params: params.merge(dpop_jkt: 'nope')
      expect(Rack::Utils.parse_query(URI.parse(response.location).query)['error']).to eql('invalid_request')
    end
  end

  describe 'a proof sent with the pushed request' do
    let(:par_url) { 'http://www.example.com/oauth/par' }
    let(:params) do
      {
        response_type: 'code', redirect_uri: client.redirect_uris[0], scope: 'admin',
        code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
      }
    end

    it 'binds the request to the key of the proof (Section 10.1)' do
      post '/oauth/par', params: params, headers: { 'Authorization' => credentials, 'DPoP' => dpop_proof(url: par_url) }
      expect(response).to have_http_status(:created)
      expect(PushedAuthorizationRequest.last.parameters['dpop_jkt']).to eql(dpop_thumbprint)
    end

    it 'refuses a dpop_jkt that is not the key of the proof' do
      post '/oauth/par', params: params.merge(dpop_jkt: 'a' * 43), headers: { 'Authorization' => credentials, 'DPoP' => dpop_proof(url: par_url) }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'server provided nonces' do
    let(:authorization) { create(:authorization, client: client) }

    before { allow(DpopNonce).to receive(:required?).and_return(true) }

    it 'asks for a nonce when the proof has none (Section 8)' do
      exchange(dpop_proof(url: token_url))
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to eql('use_dpop_nonce')
      expect(response.headers['DPoP-Nonce']).to eql(DpopNonce.current)
    end

    it 'accepts a proof with the nonce' do
      exchange(dpop_proof(url: token_url, claims: { nonce: DpopNonce.current }))
      expect(response).to have_http_status(:ok)
      expect(response.headers['DPoP-Nonce']).to be_present
    end

    it 'refuses a nonce that was not issued' do
      exchange(dpop_proof(url: token_url, claims: { nonce: 'forged' }))
      expect(json[:error]).to eql('use_dpop_nonce')
    end

    it 'accepts the nonce of the previous period' do
      nonce = DpopNonce.for_period((Time.current.to_i / DpopNonce::PERIOD) - 1)
      exchange(dpop_proof(url: token_url, claims: { nonce: nonce }))
      expect(response).to have_http_status(:ok)
    end

    it 'is asked of resources too' do
      token = create(:access_token, dpop_jkt: dpop_thumbprint)
      jwt = token.to_jwt
      get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => dpop_proof(url: 'http://www.example.com/oauth/me', method: 'GET', access_token: jwt) }
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to include('use_dpop_nonce')
      expect(response.headers['DPoP-Nonce']).to be_present
    end
  end
end
