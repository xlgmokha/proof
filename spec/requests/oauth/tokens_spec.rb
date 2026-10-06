# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/oauth/tokens' do
  let(:client) { create(:client) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }


  let(:json) { JSON.parse(response.body, symbolize_names: true) }
  let(:code_verifier) { PkceHelpers::PKCE_VERIFIER }

  def expect_token_response
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('application/json')
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(response.headers['Pragma']).to eql('no-cache')
  end

  def expect_error(error, status = :bad_request)
    expect(response).to have_http_status(status)
    expect(response.headers['Content-Type']).to include('application/json')
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(response.headers['Pragma']).to eql('no-cache')
    expect(json[:error]).to eql(error)
  end

  describe "POST /oauth/tokens" do
    # RFC 6749 Section 4.1.3 and RFC 7636 Section 4.5
    context "when using the authorization_code grant" do
      let(:authorization) { create(:authorization, client: client, redirect_uri: client.redirect_uris[0]) }
      let(:params) do
        {
          grant_type: 'authorization_code', code: authorization.code,
          code_verifier: code_verifier, redirect_uri: client.redirect_uris[0]
        }
      end

      context "when the code is still valid" do
        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_token_response }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to be_between(3590, 3600) }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(json[:scope]).to eql('admin') }
        specify { expect(authorization.reload).to be_revoked }

        it 'issues tokens to the authenticated client for the resource owner' do
          claims = Token.claims_for(json[:access_token])
          expect(claims[:client_id]).to eql(client.to_param)
          expect(claims[:sub]).to eql(authorization.user.to_param)
          expect(claims[:scope]).to eql('admin')
        end
      end

      context "when the redirect_uri was omitted from the authorization request" do
        let(:authorization) { create(:authorization, client: client, redirect_uri: nil) }

        before { post '/oauth/tokens', params: params.except(:redirect_uri), headers: headers }

        specify { expect_token_response }
      end

      context "when the redirect_uri differs from the authorization request" do
        before { post '/oauth/tokens', params: params.merge(redirect_uri: 'https://evil.example.com/cb'), headers: headers }

        specify { expect_error('invalid_grant') }
        specify { expect(authorization.reload).not_to be_revoked }
      end

      context "when the redirect_uri was sent in the authorization request but not here" do
        before { post '/oauth/tokens', params: params.except(:redirect_uri), headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when the code is expired" do
        let(:authorization) { create(:authorization, client: client, expired_at: 1.second.ago) }

        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when the code is not known" do
        before { post '/oauth/tokens', params: params.merge(code: SecureRandom.hex(20)), headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when the code is missing" do
        before { post '/oauth/tokens', params: params.except(:code), headers: headers }

        specify { expect_error('invalid_request') }
      end

      context "when the code was issued to another client" do
        let(:authorization) { create(:authorization, client: create(:client)) }

        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_error('invalid_grant') }
        specify { expect(authorization.reload).not_to be_revoked }
      end

      context "when the code is used twice" do
        let(:second) { JSON.parse(response.body, symbolize_names: true) }

        before do
          post '/oauth/tokens', params: params, headers: headers
          @first = JSON.parse(response.body, symbolize_names: true)
          post '/oauth/tokens', params: params, headers: headers
        end

        # RFC 6749 Section 4.1.2: tokens issued from the code are revoked.
        specify { expect_error('invalid_grant') }

        it 'revokes the tokens issued by the first use' do
          expect(Token.where(family_id: authorization.id).active).to be_empty
          expect(Token.authenticate(@first[:access_token])).to be_nil
        end
      end

      context "when the code_verifier does not match" do
        before { post '/oauth/tokens', params: params.merge(code_verifier: 'a' * 43), headers: headers }

        specify { expect_error('invalid_grant') }
        specify { expect(authorization.reload).not_to be_revoked }
      end

      context "when the code_verifier is too short" do
        before { post '/oauth/tokens', params: params.merge(code_verifier: 'invalid'), headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when the code_verifier is missing" do
        before { post '/oauth/tokens', params: params.except(:code_verifier), headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when the authorization has no code challenge" do
        let(:authorization) { create(:authorization, client: client, challenge: nil, redirect_uri: nil) }

        before { post '/oauth/tokens', params: params.except(:redirect_uri), headers: headers }

        # PKCE is required (RFC 9700 Section 2.1.1).
        specify { expect_error('invalid_grant') }
      end

      context "when the client is public" do
        let(:client) { create(:client, :public) }

        before { post '/oauth/tokens', params: params.merge(client_id: client.to_param) }

        specify { expect_token_response }
        specify { expect(json[:access_token]).to be_present }
      end
    end

    context "when requesting a token using the client_credentials grant" do
      context "when the client credentials are valid" do
        before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: headers }

        specify { expect_token_response }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to be_between(3590, 3600) }
        # RFC 6749 Section 4.4.3: a refresh token should not be included.
        specify { expect(json[:refresh_token]).to be_nil }
        specify { expect(json[:scope]).to eql('admin') }
      end

      context "when the scope is not supported" do
        before { post '/oauth/tokens', params: { grant_type: 'client_credentials', scope: 'nope' }, headers: headers }

        specify { expect_error('invalid_scope') }
      end

      context "when the client is public" do
        let(:client) { create(:client, :public).tap { |x| x.update_columns(grant_types: GrantTypes::ALL) } }

        before { post '/oauth/tokens', params: { grant_type: 'client_credentials', client_id: client.to_param } }

        specify { expect_error('unauthorized_client') }
      end

      context "when the credentials are unknown" do
        let(:headers) { { 'Authorization' => 'invalid' } }

        before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: headers }

        specify { expect_error('invalid_client', :unauthorized) }
      end
    end

    context "when the resource owner password credentials grant is requested" do
      let(:user) { create(:user) }

      before { post '/oauth/tokens', params: { grant_type: 'password', username: user.email, password: user.password }, headers: headers }

      # RFC 9700 Section 2.4
      specify { expect_error('unsupported_grant_type') }
    end

    # RFC 6749 Section 6 with the rotation required by RFC 9700 Section 4.14.
    context "when exchanging a refresh token for a new access token" do
      let(:authorization) { create(:authorization, client: client) }
      let(:refresh_token) { authorization.issue_tokens_to(client).last }
      let(:params) { { grant_type: 'refresh_token', refresh_token: refresh_token.to_jwt } }

      context "when the refresh token is still active" do
        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_token_response }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(json[:refresh_token]).not_to eql(refresh_token.to_jwt) }
        specify { expect(json[:scope]).to eql('admin') }
        specify { expect(refresh_token.reload).to be_revoked }

        it 'keeps the tokens in the family of the authorization' do
          expect(Token.from_jwt(json[:refresh_token], token_type: :refresh).family_id).to eql(authorization.id)
        end
      end

      context "when the refresh token is used twice" do
        before do
          post '/oauth/tokens', params: params, headers: headers
          @rotated = JSON.parse(response.body, symbolize_names: true)
          post '/oauth/tokens', params: params, headers: headers
        end

        specify { expect_error('invalid_grant') }

        it 'revokes every token of the family' do
          expect(Token.where(family_id: authorization.id).active).to be_empty
          expect(Token.authenticate(@rotated[:access_token])).to be_nil
        end
      end

      context "when the refresh token is expired" do
        let(:refresh_token) { create(:refresh_token, :expired, audience: client) }

        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when an access token is presented as a refresh token" do
        let(:refresh_token) { create(:access_token, audience: client) }

        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_error('invalid_grant') }
        specify { expect(refresh_token.reload).not_to be_revoked }
      end

      context "when the refresh token was issued to another client" do
        let(:refresh_token) { create(:refresh_token, audience: create(:client)) }

        before { post '/oauth/tokens', params: params, headers: headers }

        specify { expect_error('invalid_grant') }
        specify { expect(refresh_token.reload).not_to be_revoked }
      end

      context "when the refresh token is not a token of this server" do
        before { post '/oauth/tokens', params: params.merge(refresh_token: 'nope'), headers: headers }

        specify { expect_error('invalid_grant') }
      end

      context "when the refresh_token is missing" do
        before { post '/oauth/tokens', params: params.except(:refresh_token), headers: headers }

        specify { expect_error('invalid_request') }
      end

      context "when requesting a narrower scope" do
        let(:refresh_token) { create(:refresh_token, audience: client, scope: 'admin') }

        before { post '/oauth/tokens', params: params.merge(scope: 'admin'), headers: headers }

        specify { expect(json[:scope]).to eql('admin') }
      end

      context "when requesting a scope the original grant did not include" do
        let(:refresh_token) { create(:refresh_token, audience: client, scope: nil) }

        before { post '/oauth/tokens', params: params.merge(scope: 'admin'), headers: headers }

        specify { expect_error('invalid_scope') }
        specify { expect(refresh_token.reload).not_to be_revoked }
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

    # RFC 7523 Section 3: an assertion is only used up by a successful grant.
    context "when the grant fails for another reason" do
      let(:claims) { super().merge(sub: SecureRandom.uuid) }

      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(UsedAssertion.count).to be_zero }
    end

    context "when the scope is not supported" do
      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion, scope: 'nope' }, headers: headers }

      specify { expect_error('invalid_scope') }
    end

    context "when the jti is unreasonably long" do
      let(:claims) { super().merge(jti: 'a' * 300) }

      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(UsedAssertion.count).to be_zero }
    end

    context "when the assertion is within the clock skew leeway of its expiry" do
      let(:claims) { super().merge(exp: 30.seconds.ago.to_i) }

      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }

      it 'remembers the jti for as long as the assertion could be accepted' do
        expect(UsedAssertion.last.expires_at.to_i).to eql(claims[:exp] + JwtBearerAssertion::LEEWAY.to_i)
      end
    end

    context "when the assertion is past the clock skew leeway" do
      let(:claims) { super().merge(exp: (JwtBearerAssertion::LEEWAY + 5.seconds).ago.to_i) }

      before { post '/oauth/tokens', params: { grant_type: grant_type, assertion: assertion }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
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

        # RFC 7009 Section 2.1: the request is refused.
        specify { expect_error('invalid_request') }
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

  # RFC 7662 Section 2.2
  describe "POST /oauth/tokens/introspect response" do
    let(:token) { create(:access_token, scope: 'admin') }

    before { post '/oauth/tokens/introspect', params: { token: token.to_jwt, token_type_hint: 'access_token' }, headers: headers }

    specify { expect(json[:active]).to be(true) }
    specify { expect(json[:scope]).to eql('admin') }
    specify { expect(json[:client_id]).to eql(token.audience.to_param) }
    specify { expect(json[:token_type]).to eql('Bearer') }
    specify { expect(json[:username]).to eql(token.subject.email) }
    specify { expect(json[:nbf]).to eql(token.claims[:nbf]) }
    specify { expect(json[:jti]).to eql(token.id) }
    specify { expect(response.headers['Cache-Control']).to include('no-store') }
  end

  describe "POST /oauth/tokens/introspect edge cases" do
    context "when the hint is wrong" do
      let(:token) { create(:refresh_token) }

      before { post '/oauth/tokens/introspect', params: { token: token.to_jwt, token_type_hint: 'access_token' }, headers: headers }

      # RFC 7662 Section 2.1: the server extends its search beyond the hint.
      specify { expect(json[:active]).to be(true) }
    end

    context "when the token is not a token of this server" do
      before { post '/oauth/tokens/introspect', params: { token: 'garbage' }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json).to eql(active: false) }
    end

    context "when the token is missing" do
      before { post '/oauth/tokens/introspect', headers: headers }

      specify { expect_error('invalid_request') }
    end

    context "when the caller is not authenticated" do
      before { post '/oauth/tokens/introspect', params: { token: create(:access_token).to_jwt } }

      specify { expect_error('invalid_client', :unauthorized) }
    end
  end

  describe "POST /oauth/tokens/revoke edge cases" do
    context "when the token is unknown" do
      before { post '/oauth/tokens/revoke', params: { token: 'garbage' }, headers: headers }

      # RFC 7009 Section 2.2: invalid tokens are not an error.
      specify { expect(response).to have_http_status(:ok) }
    end

    context "when the caller is not authenticated" do
      before { post '/oauth/tokens/revoke', params: { token: create(:access_token).to_jwt } }

      specify { expect_error('invalid_client', :unauthorized) }
    end

    context "when a refresh token is revoked" do
      let(:authorization) { create(:authorization, client: client) }
      let(:tokens) { authorization.issue_tokens_to(client) }

      before do
        post '/oauth/tokens/revoke', params: { token: tokens.last.to_jwt, token_type_hint: 'refresh_token' }, headers: headers
      end

      # RFC 7009 Section 2.1
      specify { expect(tokens.map(&:reload)).to all(be_revoked) }
    end

    context "when the token is revoked, it can no longer be introspected or used" do
      let(:token) { create(:access_token, audience: client) }

      before do
        post '/oauth/tokens/revoke', params: { token: token.to_jwt }, headers: headers
        post '/oauth/tokens/introspect', params: { token: token.to_jwt }, headers: headers
      end

      specify { expect(json[:active]).to be(false) }
    end
  end

  # RFC 6749 Section 2.3 and RFC 7523 Section 2.2
  describe "client authentication" do
    context "when the credentials are form-urlencoded in the Basic header" do
      let(:client) { create(:client) }
      let(:encoded) { Base64.strict_encode64("#{URI.encode_www_form_component(client.to_param)}:#{URI.encode_www_form_component(client.password)}") }

      before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: { 'Authorization' => "Basic #{encoded}" } }

      specify { expect(response).to have_http_status(:ok) }
    end

    context "when more than one method is used" do
      let(:client) { create(:client, token_endpoint_auth_method: :client_secret_post) }

      before do
        post '/oauth/tokens',
          params: { grant_type: 'client_credentials', client_id: client.to_param, client_secret: client.password },
          headers: headers
      end

      specify { expect_error('invalid_request') }
    end

    context "when no credentials are presented" do
      before { post '/oauth/tokens', params: { grant_type: 'client_credentials' } }

      specify { expect_error('invalid_client', :unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to start_with('Basic') }
    end

    context "when a confidential client only presents its client_id" do
      before { post '/oauth/tokens', params: { grant_type: 'client_credentials', client_id: client.to_param } }

      specify { expect_error('invalid_client', :unauthorized) }
    end

    context "when the client authenticates with a private_key_jwt" do
      let(:signing_key) { OpenSSL::PKey::RSA.generate(2048) }
      let(:jwk) { JWT::JWK.new(signing_key.public_key, kid: 'key-1') }
      let(:client) { create(:client, token_endpoint_auth_method: :private_key_jwt, jwks_uri: nil, jwks: { keys: [jwk.export] }) }
      let(:claims) { { iss: client.to_param, sub: client.to_param, aud: oauth_tokens_url, exp: 5.minutes.from_now.to_i, jti: SecureRandom.uuid } }
      let(:assertion) { JWT.encode(claims, signing_key, 'RS256', kid: 'key-1') }
      let(:params) do
        {
          grant_type: 'client_credentials', client_id: client.to_param,
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer', client_assertion: assertion
        }
      end

      context "when the assertion is valid" do
        before { post '/oauth/tokens', params: params }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(json[:access_token]).to be_present }
      end

      context "when the subject is not the client" do
        let(:claims) { { iss: client.to_param, sub: SecureRandom.uuid, aud: oauth_tokens_url, exp: 5.minutes.from_now.to_i, jti: SecureRandom.uuid } }

        before { post '/oauth/tokens', params: params }

        specify { expect_error('invalid_client', :unauthorized) }
      end

      context "when the assertion is replayed" do
        before do
          post '/oauth/tokens', params: params
          post '/oauth/tokens', params: params
        end

        specify { expect_error('invalid_client', :unauthorized) }
      end

      context "when the assertion is signed with another key" do
        let(:assertion) { JWT.encode(claims, OpenSSL::PKey::RSA.generate(2048), 'RS256', kid: 'key-1') }

        before { post '/oauth/tokens', params: params }

        specify { expect_error('invalid_client', :unauthorized) }
      end

      context "when the client is not registered for private_key_jwt" do
        let(:client) { create(:client, jwks_uri: nil, jwks: { keys: [jwk.export] }) }

        before { post '/oauth/tokens', params: params }

        specify { expect_error('invalid_client', :unauthorized) }
      end
    end
  end
end
