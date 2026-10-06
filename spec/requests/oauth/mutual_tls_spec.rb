# frozen_string_literal: true

require 'rails_helper'

# RFC 8705: OAuth 2.0 Mutual-TLS Client Authentication and Certificate-Bound Access Tokens
RSpec.describe 'mutual TLS' do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:certificate) { build_certificate(key: key, dns: 'client.example.com') }
  let(:other_certificate) { build_certificate(dns: 'other.example.com') }
  let(:jwk) { JWT::JWK.new(key.public_key, kid: 'k1') }

  before { allow(ClientCertificate).to receive(:enabled?).and_return(true) }

  def token_request(client, certificate, extra = {})
    headers = certificate ? certificate_header(certificate) : {}
    post '/oauth/tokens', params: { grant_type: 'client_credentials', client_id: client.to_param }.merge(extra), headers: headers
  end

  describe 'tls_client_auth (Section 2.1)' do
    let(:client) { create(:client, token_endpoint_auth_method: :tls_client_auth, tls_client_auth_san_dns: 'client.example.com') }

    it 'authenticates by the registered subject alternative name' do
      token_request(client, certificate)
      expect(response).to have_http_status(:ok)
      expect(json[:access_token]).to be_present
    end

    it 'refuses another certificate' do
      token_request(client, other_certificate)
      expect(response).to have_http_status(:unauthorized)
      expect(json[:error]).to eql('invalid_client')
    end

    it 'refuses a request without a certificate' do
      token_request(client, nil)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'authenticates by subject DN' do
      dn_client = create(:client, token_endpoint_auth_method: :tls_client_auth, tls_client_auth_subject_dn: 'CN=client.example.com')
      token_request(dn_client, certificate)
      expect(response).to have_http_status(:ok)
    end

    it 'requires exactly one identifier at registration' do
      expect(build(:client, token_endpoint_auth_method: :tls_client_auth)).to be_invalid
      expect(build(:client, token_endpoint_auth_method: :tls_client_auth, tls_client_auth_san_dns: 'a', tls_client_auth_subject_dn: 'CN=a')).to be_invalid
    end
  end

  describe 'self_signed_tls_client_auth (Section 2.2)' do
    let(:client) { create(:client, token_endpoint_auth_method: :self_signed_tls_client_auth, jwks_uri: nil, jwks: { keys: [jwk.export] }) }

    it 'authenticates a certificate with the registered key' do
      token_request(client, certificate)
      expect(response).to have_http_status(:ok)
    end

    it 'refuses a certificate with another key' do
      token_request(client, other_certificate)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'needs registered keys' do
      expect(build(:client, token_endpoint_auth_method: :self_signed_tls_client_auth, jwks_uri: nil)).to be_invalid
    end
  end

  describe 'a client that does not use certificates' do
    let(:client) { create(:client, token_endpoint_auth_method: :tls_client_auth, tls_client_auth_san_dns: 'client.example.com') }

    it 'is not trusted on the strength of a certificate header alone when mTLS is off' do
      allow(ClientCertificate).to receive(:enabled?).and_return(false)
      token_request(client, certificate)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'certificate-bound access tokens (Section 3)' do
    let(:client) do
      create(:client, token_endpoint_auth_method: :tls_client_auth, tls_client_auth_san_dns: 'client.example.com',
        tls_client_certificate_bound_access_tokens: true)
    end

    it 'binds the token to the certificate through cnf' do
      token_request(client, certificate)
      expect(Token.claims_for(json[:access_token])[:cnf]).to eql('x5t#S256' => certificate_thumbprint(certificate))
    end

    context 'when the token is used' do
      let(:jwt) { token_request(client, certificate) && json[:access_token] }
      let(:user_token) { create(:access_token, x5t_s256: certificate_thumbprint(certificate)) }

      it 'is accepted over the same certificate' do
        get '/oauth/me', headers: certificate_header(certificate).merge('Authorization' => "Bearer #{user_token.to_jwt}")
        expect(response).to have_http_status(:ok)
      end

      it 'is refused over another certificate' do
        get '/oauth/me', headers: certificate_header(other_certificate).merge('Authorization' => "Bearer #{user_token.to_jwt}")
        expect(response).to have_http_status(:unauthorized)
      end

      it 'is refused without a certificate' do
        get '/oauth/me', headers: { 'Authorization' => "Bearer #{user_token.to_jwt}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'is not accepted by resources that cannot check certificates' do
        expect(Token.authenticate(user_token.to_jwt)).to be_nil
      end
    end

    it 'insists on a certificate when the client asked for bound tokens' do
      bound = create(:client, tls_client_certificate_bound_access_tokens: true)
      post '/oauth/tokens', params: { grant_type: 'client_credentials' },
        headers: { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(bound.to_param, bound.password) }
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to eql('invalid_request')
    end
  end

  describe 'introspection of a bound token' do
    it 'reports the confirmation' do
      client = create(:client)
      token = create(:access_token, audience: client, x5t_s256: certificate_thumbprint(certificate))
      post '/oauth/tokens/introspect', params: { token: token.to_jwt },
        headers: { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
      expect(json[:cnf]).to eql('x5t#S256': certificate_thumbprint(certificate))
    end
  end

  describe 'metadata and registration' do
    it 'advertises the methods when enabled (Section 4)' do
      get '/.well-known/oauth-authorization-server'
      expect(json[:token_endpoint_auth_methods_supported]).to include('tls_client_auth', 'self_signed_tls_client_auth')
      expect(json[:tls_client_certificate_bound_access_tokens]).to be(true)
    end

    it 'does not advertise them when disabled' do
      allow(ClientCertificate).to receive(:enabled?).and_return(false)
      get '/.well-known/oauth-authorization-server'
      expect(json[:token_endpoint_auth_methods_supported]).not_to include('tls_client_auth')
      expect(json).not_to have_key(:tls_client_certificate_bound_access_tokens)
    end

    it 'registers certificate metadata (Section 2.1.2)' do
      post '/oauth/clients', params: {
        client_name: 'App', grant_types: %w[client_credentials], token_endpoint_auth_method: 'tls_client_auth',
        tls_client_auth_san_dns: 'client.example.com', tls_client_certificate_bound_access_tokens: true
      }
      expect(response).to have_http_status(:created)
      expect(json[:token_endpoint_auth_method]).to eql('tls_client_auth')
      expect(json[:tls_client_auth_san_dns]).to eql('client.example.com')
      expect(json[:tls_client_certificate_bound_access_tokens]).to be(true)
    end
  end
end
