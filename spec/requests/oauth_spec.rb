require 'rails_helper'

RSpec.describe '/oauth' do
  context "when the user is logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /oauth" do
      let(:state) { SecureRandom.uuid  }

      context "when the client id is known" do
        let(:client) { create(:client) }

        context "when the correct parameters are provided" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'code', state: state } }
          specify { expect(response).to have_http_status(:ok) }
          specify { expect(response.body).to include(client.name) }
          specify { expect(response.body).to include(state) }
        end

        context "when an incorrect response_type is provided" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'invalid' } }

          specify { expect(response).to have_http_status(:not_found) }
        end
      end
    end

    describe "GET /oauth/authorize" do
      let(:state) { SecureRandom.uuid  }

      context "when the client id is known" do
        let(:client) { create(:client) }
        before { get "/oauth/authorize", params: { client_id: client.to_param, response_type: 'code', state: state } }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include(client.name) }
        specify { expect(response.body).to include(state) }
      end
    end

    describe "POST /oauth" do
      context "when the client id is known" do
        let(:client) { create(:client) }
        let(:state) { SecureRandom.uuid }

        before { post "/oauth", params: { client_id: client.to_param, state: state } }

        specify { expect(response).to redirect_to(client.redirect_uri_path(code: Authorization.last.code, state: state)) }
      end
    end
  end

  describe "POST /oauth/token" do
    let(:client) { create(:client) }
    let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.uuid, client.secret) }
    let(:headers) { { 'Authorization' => credentials } }

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
end
