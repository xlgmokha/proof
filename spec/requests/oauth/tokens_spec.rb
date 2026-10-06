# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/oauth/tokens' do
  let(:client) { create(:client) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }

  describe "POST /oauth/tokens" do
    context "when using the authorization_code grant" do
      context "when the code is still valid" do
        let(:authorization) { create(:authorization, client: client) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(authorization.reload).to be_revoked }
      end

      context "when the code is expired" do
        let(:authorization) { create(:authorization, client: client, expired_at: 1.second.ago) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:error]).to eql('invalid_grant') }
      end

      context "when the code is not known" do
        before { post '/oauth/tokens', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        specify { expect(json[:error]).to eql('invalid_grant') }
      end

      context "when the authorization was created with the code_challenge_method of SHA256" do
        let(:code_verifier) { SecureRandom.hex(128) }
        let(:authorization) { create(:authorization, client: client, challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false), challenge_method: :sha256) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code, code_verifier: code_verifier }, headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(authorization.reload).to be_revoked }
      end

      context "when the authorization was created with the code_challenge_method of plain" do
        let(:code_verifier) { SecureRandom.hex(128) }
        let(:authorization) { create(:authorization, client: client, challenge: code_verifier, challenge_method: :plain) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code, code_verifier: code_verifier }, headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(authorization.reload).to be_revoked }
      end

      context "when the SHA256 challenge is invalid" do
        let(:code_verifier) { SecureRandom.hex(128) }
        let(:authorization) { create(:authorization, client: client, challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false), challenge_method: :sha256) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code, code_verifier: 'invalid' }, headers: headers
        end

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        specify { expect(json[:error]).to eql('invalid_grant') }
      end

      context "when the plain challenge is invalid" do
        let(:code_verifier) { SecureRandom.hex(128) }
        let(:authorization) { create(:authorization, client: client, challenge: code_verifier, challenge_method: :plain) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code, code_verifier: 'invalid' }, headers: headers
        end

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        specify { expect(json[:error]).to eql('invalid_grant') }
      end
    end

    context "when requesting a token using the client_credentials grant" do
      context "when the client credentials are valid" do
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_nil }
      end

      context "when the credentials are unknown" do
        let(:headers) { { 'Authorization' => 'invalid' } }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: headers }

        specify { expect(response).to have_http_status(:unauthorized) }
        specify { expect(json[:error]).to eql('invalid_client') }
      end
    end

    context "when requesting tokens using the resource owner password credentials grant" do
      context "when the credentials are valid" do
        let(:user) { create(:user) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'password', username: user.email, password: user.password }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
      end

      context "when the credentials are invalid" do
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'password', username: generate(:email), password: generate(:password) }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(json[:error]).to eql('invalid_grant') }
      end
    end

    context "when exchanging a refresh token for a new access token" do
      context "when the refresh token is still active" do
        let(:refresh_token) { create(:refresh_token) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before { post '/oauth/tokens', params: { grant_type: 'refresh_token', refresh_token: refresh_token.to_jwt }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(refresh_token.reload).to be_revoked }
      end
    end

    context "when exchanging a SAML 2.0 assertion grant for tokens" do
      context "when the assertion contains a valid email address" do
        let(:user) { create(:user) }
        let(:saml_request) { instance_double(Saml::Kit::AuthenticationRequest, id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: true) }
        let(:saml) { Saml::Kit::Assertion.build_xml(user, saml_request) }
        let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
          post '/oauth/tokens', params: {
            grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
            assertion: Base64.urlsafe_encode64(saml),
          }, headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
      end

      context "when the assertion contains a valid uuid" do
        let(:user) { create(:user) }
        let(:saml_request) { instance_double(Saml::Kit::AuthenticationRequest, id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: true, name_id_format: Saml::Kit::Namespaces::PERSISTENT) }
        let(:saml) { Saml::Kit::Assertion.build_xml(user, saml_request) }
        let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
          post '/oauth/tokens', params: {
            grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
            assertion: Base64.urlsafe_encode64(saml),
          }, headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
      end
    end

    context "when the assertion is not a valid document" do
      let(:user) { create(:user) }
      let(:saml_request) { instance_double(Saml::Kit::AuthenticationRequest, id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id) }
      let(:saml) { 'invalid' }
      let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before do
        allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
        post '/oauth/tokens', params: {
          grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
          assertion: Base64.urlsafe_encode64(saml),
        }, headers: headers
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(response.headers['Content-Type']).to include('application/json') }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(response.headers['Pragma']).to eql('no-cache') }
      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion has an invalid signature" do
      let(:user) { create(:user) }
      let(:saml_request) { instance_double(Saml::Kit::AuthenticationRequest, id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: false) }
      let(:key_pair) { Xml::Kit::KeyPair.generate(use: :signing) }
      let(:saml) { Saml::Kit::Assertion.build_xml(user, saml_request) { |x| x.sign_with(key_pair) } }
      let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before do
        allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
        post '/oauth/tokens', params: {
          grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
          assertion: Base64.urlsafe_encode64(saml),
        }, headers: headers
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(response.headers['Content-Type']).to include('application/json') }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(response.headers['Pragma']).to eql('no-cache') }

      specify { expect(json[:error]).to eql('invalid_grant') }
    end
  end

  describe "POST /oauth/tokens error handling" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    context "when the grant_type is missing" do
      before { post '/oauth/tokens', headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end

    context "when the grant_type is not supported" do
      before { post '/oauth/tokens', params: { grant_type: 'implicit' }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('unsupported_grant_type') }
    end

    context "when the client credentials are wrong" do
      before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, 'wrong') } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to start_with('Basic') }
      specify { expect(json[:error]).to eql('invalid_client') }
    end
  end

  describe "POST /oauth/tokens with client_secret_post authentication" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    context "when the client is registered for client_secret_post" do
      let(:client) { create(:client, token_endpoint_auth_method: :client_secret_post) }

      before do
        post '/oauth/tokens', params: { grant_type: 'client_credentials', client_id: client.to_param, client_secret: client.password }
      end

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json[:access_token]).to be_present }
    end

    context "when the client is registered for client_secret_basic" do
      before do
        post '/oauth/tokens', params: { grant_type: 'client_credentials', client_id: client.to_param, client_secret: client.password }
      end

      specify { expect(response).to have_http_status(:unauthorized) }
    end

    context "when the secret is wrong" do
      let(:client) { create(:client, token_endpoint_auth_method: :client_secret_post) }

      before do
        post '/oauth/tokens', params: { grant_type: 'client_credentials', client_id: client.to_param, client_secret: 'wrong' }
      end

      specify { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe "POST /oauth/tokens with the jwt-bearer grant (RFC 7523)" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }
    let(:grant_type) { 'urn:ietf:params:oauth:grant-type:jwt-bearer' }
    let(:signing_key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:jwk) { JWT::JWK.new(signing_key.public_key, kid: 'key-1') }
    let(:client) { create(:client, jwks_uri: nil, jwks: { keys: [jwk.export] }) }
    let(:user) { create(:user) }
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }
    let(:claims) do
      {
        iss: client.to_param, sub: user.to_param, aud: oauth_tokens_url,
        exp: 5.minutes.from_now.to_i, jti: SecureRandom.uuid
      }
    end
    let(:assertion) { JWT.encode(claims, signing_key, 'RS256', kid: 'key-1') }

    before { allow(Rails).to receive(:cache).and_return(cache) }

    context "when the assertion is valid" do
      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(json[:token_type]).to eql('Bearer') }
      specify { expect(json[:refresh_token]).to be_present }
      specify { expect(Token.claims_for(json[:access_token])[:sub]).to eql(user.to_param) }
    end

    context "when the subject is identified by email" do
      before do
        claims[:sub] = user.email
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(response).to have_http_status(:ok) }
    end

    context "when the keys are published at a jwks_uri" do
      let(:client) { create(:client, jwks_uri: 'https://example.com/jwks.json') }

      before do
        fetcher = JwksFetcher.new
        allow(fetcher).to receive(:fetch).and_return({ "keys" => [jwk.export.stringify_keys] })
        allow(JwksFetcher).to receive(:new).and_return(fetcher)
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(response).to have_http_status(:ok) }
    end

    context "when the assertion is signed with an unknown key" do
      let(:assertion) { JWT.encode(claims, OpenSSL::PKey::RSA.generate(2048), 'RS256', kid: 'key-1') }

      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion uses a symmetric algorithm" do
      let(:assertion) { JWT.encode(claims, client.password, 'HS256') }

      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion was issued by a different client" do
      before do
        claims[:iss] = SecureRandom.uuid
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the audience is not this server" do
      before do
        claims[:aud] = 'https://other.example.com/token'
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion is expired" do
      before do
        claims[:exp] = 10.minutes.ago.to_i
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion has no expiration" do
      before do
        claims.delete(:exp)
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion lifetime is too long" do
      before do
        claims[:exp] = 1.day.from_now.to_i
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion is replayed" do
      before do
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the subject is unknown" do
      before do
        claims[:sub] = SecureRandom.uuid
        post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context "when the assertion is missing" do
      before { post '/oauth/tokens', params: { grant_type: grant_type }, headers: headers }

      specify { expect(json[:error]).to eql('invalid_grant') }
    end
  end

  describe "POST /oauth/tokens/introspect" do
    context "when the access_token is valid" do
      let(:token) { create(:access_token) }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      specify { expect(response.headers['Set-Cookie']).to be_nil }
      specify { expect(json[:active]).to be(true) }
      specify { expect(json[:sub]).to eql(token.claims[:sub]) }
      specify { expect(json[:aud]).to eql(token.claims[:aud]) }
      specify { expect(json[:iss]).to eql(token.claims[:iss]) }
      specify { expect(json[:exp]).to eql(token.claims[:exp]) }
      specify { expect(json[:iat]).to eql(token.claims[:iat]) }
    end

    context "when the refresh_token is valid" do
      let(:token) { create(:refresh_token) }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      specify { expect(json[:active]).to be(true) }
      specify { expect(json[:sub]).to eql(token.claims[:sub]) }
      specify { expect(json[:aud]).to eql(token.claims[:aud]) }
      specify { expect(json[:iss]).to eql(token.claims[:iss]) }
      specify { expect(json[:exp]).to eql(token.claims[:exp]) }
      specify { expect(json[:iat]).to eql(token.claims[:iat]) }
    end

    context "when the token is revoked" do
      let(:token) { create(:access_token, :revoked) }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      specify { expect(json[:active]).to be(false) }
    end

    context "when the token is expired" do
      let(:token) { create(:access_token, :expired) }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      specify { expect(json[:active]).to be(false) }
    end
  end

  describe "POST /oauth/tokens/revoke" do
    context "when the client credentials are valid" do
      context "when the access token is active and known" do
        let(:token) { create(:access_token, audience: client) }

        before { post '/oauth/tokens/revoke', params: { token: token.to_jwt, token_type_hint: :access_token }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to be_empty }
        specify { expect(token.reload).to be_revoked }
      end

      context "when the token was not issued to this client" do
        let(:token) { create(:access_token, audience: other_client) }
        let(:other_client) { create(:client) }

        before { post '/oauth/tokens/revoke', params: { token: token.to_jwt, token_type_hint: :access_token }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(token.reload).not_to be_revoked }
      end

      context "when the refresh token is active and known" do
        let(:token) { create(:refresh_token, audience: client) }

        before { post '/oauth/tokens/revoke', params: { token: token.to_jwt, token_type_hint: :refresh_token }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to be_empty }
        specify { expect(token.reload).to be_revoked }
      end

      context "when the access token is expired" do
        let(:token) { create(:access_token, :expired, audience: client) }

        before { post '/oauth/tokens/revoke', params: { token: token.to_jwt, token_type_hint: :refresh_token }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
      end
    end
  end
end
