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
        specify { expect(json[:error]).to eql('invalid_request') }
      end

      context "when the code is not known" do
        before { post '/oauth/tokens', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        specify { expect(json[:error]).to eql('invalid_request') }
      end

      context "when the authorization was created with the code_challenge_method of SHA256" do
        let(:code_verifier) { SecureRandom.hex(128) }
        let(:authorization) { create(:authorization, client: client, challenge: Base64.urlsafe_encode64(Digest::SHA256.hexdigest(code_verifier)), challenge_method: :sha256) }
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
        let(:authorization) { create(:authorization, client: client, challenge: Base64.urlsafe_encode64(Digest::SHA256.hexdigest(code_verifier)), challenge_method: :sha256) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }

        before do
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers
          post '/oauth/tokens', params: { grant_type: 'authorization_code', code: authorization.code, code_verifier: 'invalid' }, headers: headers
        end

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        specify { expect(json[:error]).to eql('invalid_request') }
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

        specify { expect(json[:error]).to eql('invalid_request') }
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
        specify { expect(json[:error]).to eql('invalid_request') }
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
      specify { expect(json[:error]).to eql('invalid_request') }
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

      specify { expect(json[:error]).to eql('invalid_request') }
    end
  end

  describe "POST /oauth/tokens/introspect" do
    context "when the access_token is valid" do
      let(:token) { create(:access_token) }
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
