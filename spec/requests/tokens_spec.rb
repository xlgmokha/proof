require 'rails_helper'

RSpec.describe '/tokens' do
  let(:client) { create(:client) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.uuid, client.secret) }
  let(:headers) { { 'Authorization' => credentials } }

  describe "POST /oauth/token" do
    context "when using the authorization_code grant" do
      context "when the code is still valid" do
        let(:authorization) { create(:authorization, client: client) }

        before { post '/oauth/token', params: { grant_type: 'authorization_code', code: authorization.code }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(authorization.reload).to be_revoked }
      end

      context "when the code is expired" do
        let(:authorization) { create(:authorization, client: client, expired_at: 1.second.ago) }

        before { post '/oauth/token', params: { grant_type: 'authorization_code', code: authorization.code }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:error]).to eql('invalid_request') }
      end

      context "when the code is not known" do
        before { post '/oauth/token', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:error]).to eql('invalid_request') }
      end
    end

    context "when requesting a token using the client_credentials grant" do
      context "when the client credentials are valid" do
        before { post '/oauth/token', params: { grant_type: 'client_credentials' }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_nil }
      end

      context "when the credentials are unknown" do
        let(:headers) { { 'Authorization' => 'invalid' } }
        before { post '/oauth/token', params: { grant_type: 'client_credentials' }, headers: headers }

        specify { expect(response).to have_http_status(:unauthorized) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:error]).to eql('invalid_client') }
      end
    end

    context "when requesting tokens using the resource owner password credentials grant" do
      context "when the credentials are valid" do
        let(:user) { create(:user) }
        before { post '/oauth/token', params: { grant_type: 'password', username: user.email, password: user.password }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
      end

      context "when the credentials are invalid" do
        before { post '/oauth/token', params: { grant_type: 'password', username: generate(:email), password: generate(:password) }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:error]).to eql('invalid_request') }
      end
    end

    context "when exchanging a refresh token for a new access token" do
      context "when the refresh token is still active" do
        let(:refresh_token) { create(:refresh_token) }

        before { post '/oauth/token', params: { grant_type: 'refresh_token', refresh_token: refresh_token.to_jwt }, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
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
        let(:saml_request) { double(id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: true) }
        let(:saml) { Saml::Kit::Assertion.build_xml(user, saml_request) }
        let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }

        before :each do
          allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
          post '/oauth/token', params: {
            grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
            assertion: Base64.urlsafe_encode64(saml),
          }, headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
      end

      context "when the assertion contains a valid uuid" do
        let(:user) { create(:user) }
        let(:saml_request) { double(id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: true, name_id_format: Saml::Kit::Namespaces::PERSISTENT) }
        let(:saml) { Saml::Kit::Assertion.build_xml(user, saml_request) }
        let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }

        before :each do
          allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
          post '/oauth/token', params: {
            grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
            assertion: Base64.urlsafe_encode64(saml),
          }, headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to eql('Bearer') }
        specify { expect(json[:expires_in]).to eql(1.hour.to_i) }
        specify { expect(json[:refresh_token]).to be_present }
      end
    end

    context "when the assertion is not a valid document" do
      let(:user) { create(:user) }
      let(:saml_request) { double(id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id) }
      let(:saml) { 'invalid' }
      let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }

      before :each do
        allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
        post '/oauth/token', params: {
          grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
          assertion: Base64.urlsafe_encode64(saml),
        }, headers: headers
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(response.headers['Content-Type']).to include('application/json') }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(response.headers['Pragma']).to eql('no-cache') }

      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end

    context "when the assertion has an invalid signature" do
      let(:user) { create(:user) }
      let(:saml_request) { double(id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: false) }
      let(:key_pair) { Xml::Kit::KeyPair.generate(use: :signing) }
      let(:saml) { Saml::Kit::Assertion.build_xml(user, saml_request) { |x| x.sign_with(key_pair) } }
      let(:metadata) { Saml::Kit::Metadata.build(&:build_identity_provider) }

      before :each do
        allow(Saml::Kit.configuration.registry).to receive(:metadata_for).and_return(metadata)
        post '/oauth/token', params: {
          grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
          assertion: Base64.urlsafe_encode64(saml),
        }, headers: headers
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(response.headers['Content-Type']).to include('application/json') }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(response.headers['Pragma']).to eql('no-cache') }

      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:error]).to eql('invalid_request') }
    end
  end

  describe "POST /tokens/introspect" do
    context "when the access_token is valid" do
      let(:token) { create(:access_token) }

      before { post '/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:active]).to eql(true) }
      specify { expect(json[:sub]).to eql(token.claims[:sub]) }
      specify { expect(json[:aud]).to eql(token.claims[:aud]) }
      specify { expect(json[:iss]).to eql(token.claims[:iss]) }
      specify { expect(json[:exp]).to eql(token.claims[:exp]) }
      specify { expect(json[:iat]).to eql(token.claims[:iat]) }
    end

    context "when the refresh_token is valid" do
      let(:token) { create(:refresh_token) }

      before { post '/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:active]).to eql(true) }
      specify { expect(json[:sub]).to eql(token.claims[:sub]) }
      specify { expect(json[:aud]).to eql(token.claims[:aud]) }
      specify { expect(json[:iss]).to eql(token.claims[:iss]) }
      specify { expect(json[:exp]).to eql(token.claims[:exp]) }
      specify { expect(json[:iat]).to eql(token.claims[:iat]) }
    end

    context "when the token is revoked" do
      let(:token) { create(:access_token, :revoked) }

      before { post '/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:active]).to eql(false) }
    end

    context "when the token is expired" do
      let(:token) { create(:access_token, :expired) }

      before { post '/tokens/introspect', params: { token: token.to_jwt }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:active]).to eql(false) }
    end
  end
end
