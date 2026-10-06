# frozen_string_literal: true

require 'rails_helper'

# RFC 9449: Demonstrating Proof of Possession
RSpec.describe 'DPoP' do
  let(:client) { create(:client) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:token_url) { 'http://www.example.com/oauth/tokens' }
  let(:authorization) { create(:authorization, client: client) }
  let(:grant) do
    { grant_type: 'authorization_code', code: authorization.code, code_verifier: PkceHelpers::PKCE_VERIFIER }
  end

  def exchange(proof, params = grant)
    headers = { 'Authorization' => credentials }
    headers['DPoP'] = proof if proof
    post '/oauth/tokens', params: params, headers: headers
  end

  describe 'at the token endpoint' do
    context 'when a valid proof is sent' do
      before { exchange(dpop_proof(url: token_url)) }

      specify { expect(response).to have_http_status(:ok) }
      # Section 5
      specify { expect(json[:token_type]).to eql('DPoP') }

      it 'binds the access token to the key of the proof (Section 6)' do
        claims = Token.claims_for(json[:access_token])
        expect(claims[:cnf]).to eql('jkt' => dpop_thumbprint)
      end

      it 'binds the refresh token to the key as well' do
        expect(Token.from_jwt(json[:refresh_token], token_type: :refresh).dpop_jkt).to eql(dpop_thumbprint)
      end
    end

    context 'when the proof carries the query of the url' do
      before { exchange(dpop_proof(url: "#{token_url}?ignored=1")) }

      # Section 4.3: htu is compared without query and fragment.
      specify { expect(response).to have_http_status(:ok) }
    end

    context 'when no proof is sent' do
      before { exchange(nil) }

      specify { expect(json[:token_type]).to eql('Bearer') }
      specify { expect(Token.claims_for(json[:access_token])).not_to have_key(:cnf) }
    end

    {
      'the method differs' => ->(t) { t.dpop_proof(url: 'http://www.example.com/oauth/tokens', method: 'GET') },
      'the url differs' => ->(t) { t.dpop_proof(url: 'http://www.example.com/oauth/other') },
      'the proof is stale' => ->(t) { t.dpop_proof(url: 'http://www.example.com/oauth/tokens', claims: { iat: 1.hour.ago.to_i }) },
      'the proof is from the future' => ->(t) { t.dpop_proof(url: 'http://www.example.com/oauth/tokens', claims: { iat: 1.hour.from_now.to_i }) },
      'the typ is wrong' => ->(t) { t.dpop_proof(url: 'http://www.example.com/oauth/tokens', header: { typ: 'JWT' }) },
      'the jti is missing' => ->(t) { t.dpop_proof(url: 'http://www.example.com/oauth/tokens', claims: { jti: nil }) },
      'it is not a JWT' => ->(_) { 'garbage' },
    }.each do |reason, build|
      context "when #{reason}" do
        before { exchange(build.call(self)) }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(json[:error]).to eql('invalid_dpop_proof') }
        specify { expect(authorization.reload).not_to be_revoked }
      end
    end

    context 'when the proof is signed with a different key than the jwk it carries' do
      let(:other_key) { OpenSSL::PKey::EC.generate('prime256v1') }
      let(:proof) do
        JWT.encode(
          { jti: SecureRandom.uuid, htm: 'POST', htu: token_url, iat: Time.current.to_i }, other_key, 'ES256',
          { typ: 'dpop+jwt', jwk: JWT::JWK.new(dpop_key).export.except(:kid) }
        )
      end

      before { exchange(proof) }

      specify { expect(json[:error]).to eql('invalid_dpop_proof') }
    end

    context 'when the jwk includes private key material' do
      before { exchange(dpop_proof(url: token_url, header: { jwk: JWT::JWK.new(dpop_key).export(include_private: true) })) }

      specify { expect(json[:error]).to eql('invalid_dpop_proof') }
    end

    context 'when the proof uses a symmetric algorithm' do
      let(:proof) do
        JWT.encode({ jti: SecureRandom.uuid, htm: 'POST', htu: token_url, iat: Time.current.to_i }, 'secret', 'HS256',
          { typ: 'dpop+jwt', jwk: { kty: 'oct', k: 'c2VjcmV0' } })
      end

      before { exchange(proof) }

      specify { expect(json[:error]).to eql('invalid_dpop_proof') }
    end

    context 'when the proof is replayed' do
      let(:proof) { dpop_proof(url: token_url) }

      before do
        exchange(proof)
        exchange(proof, grant.merge(code: create(:authorization, client: client).code))
      end

      # Section 11.1
      specify { expect(json[:error]).to eql('invalid_dpop_proof') }
    end

    context 'when refreshing a bound refresh token' do
      let(:refresh_token) { JSON.parse(response.body, symbolize_names: true)[:refresh_token] }
      let(:refresh) { { grant_type: 'refresh_token', refresh_token: refresh_token } }

      before { exchange(dpop_proof(url: token_url)) }

      context 'with a proof from the same key' do
        before { exchange(dpop_proof(url: token_url), refresh) }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(json[:token_type]).to eql('DPoP') }
        specify { expect(Token.claims_for(json[:access_token])[:cnf]).to eql('jkt' => dpop_thumbprint) }
      end

      context 'with a proof from another key' do
        before { exchange(dpop_proof(url: token_url, key: OpenSSL::PKey::EC.generate('prime256v1')), refresh) }

        specify { expect(json[:error]).to eql('invalid_grant') }
      end

      context 'without a proof' do
        before { exchange(nil, refresh) }

        specify { expect(json[:error]).to eql('invalid_grant') }
      end
    end
  end

  describe 'at a protected resource' do
    let(:me_url) { 'http://www.example.com/oauth/me' }
    let(:token) { create(:access_token, dpop_jkt: dpop_thumbprint) }
    let(:jwt) { token.to_jwt }
    let(:proof) { dpop_proof(url: me_url, method: 'GET', access_token: jwt) }

    context 'when a bound token is presented with a matching proof' do
      before { get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof } }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json[:cnf]).to eql(jkt: dpop_thumbprint) }
    end

    context 'when a bound token is presented as a Bearer token' do
      before { get '/oauth/me', headers: { 'Authorization' => "Bearer #{jwt}" } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to start_with('Bearer').and include('error="invalid_token"') }
    end

    context 'when the proof is missing' do
      before { get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}" } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to start_with('DPoP').and include('error="invalid_dpop_proof"') }
      specify { expect(response.headers['WWW-Authenticate']).to include('algs="') }
    end

    context 'when the proof was made with another key' do
      let(:proof) { dpop_proof(url: me_url, method: 'GET', access_token: jwt, key: OpenSSL::PKey::EC.generate('prime256v1')) }

      before { get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to include('error="invalid_token"') }
    end

    context 'when the proof is for another access token' do
      let(:proof) { dpop_proof(url: me_url, method: 'GET', access_token: 'another-token') }

      before { get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to include('error="invalid_dpop_proof"') }
    end

    context 'when the proof is for another method' do
      let(:proof) { dpop_proof(url: me_url, method: 'POST', access_token: jwt) }

      before { get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof } }

      specify { expect(response).to have_http_status(:unauthorized) }
    end

    context 'when the proof is replayed' do
      before do
        get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof }
        get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof }
      end

      specify { expect(response).to have_http_status(:unauthorized) }
    end

    context 'when an unbound token is presented with the DPoP scheme' do
      let(:token) { create(:access_token) }

      before { get '/oauth/me', headers: { 'Authorization' => "DPoP #{jwt}", 'DPoP' => proof } }

      specify { expect(response).to have_http_status(:unauthorized) }
    end

    context 'when a protected resource cannot check proofs' do
      it 'does not accept a bound token' do
        expect(Token.authenticate(jwt)).to be_nil
        expect(Token.authenticate(jwt, allow_bound: true)).to eql(token)
      end
    end
  end

  describe 'the metadata' do
    before { get '/.well-known/oauth-authorization-server' }

    specify { expect(json[:dpop_signing_alg_values_supported]).to include('ES256', 'RS256', 'PS256') }
    specify { expect(json[:dpop_signing_alg_values_supported]).not_to include('none', 'HS256') }
  end

  describe 'introspection of a bound token' do
    let(:token) { create(:access_token, audience: client, dpop_jkt: dpop_thumbprint) }

    before { post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: { 'Authorization' => credentials } }

    specify { expect(json[:token_type]).to eql('DPoP') }
    specify { expect(json[:cnf]).to eql(jkt: dpop_thumbprint) }
  end
end
