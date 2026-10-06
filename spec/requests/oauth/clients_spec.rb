# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/oauth/clients" do
  describe "POST /oauth/clients" do
    let(:redirect_uris) { [generate(:uri), generate(:uri)] }
    let(:client_name) { FFaker::Name.name }
    let(:logo_uri) { generate(:uri) }
    let(:jwks_uri) { generate(:uri) }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }
    let(:last_client) { Client.order(created_at: :asc).last }

    context "when the registration request is valid" do
      before do
        post "/oauth/clients", params: {
          redirect_uris: redirect_uris,
          client_name: client_name,
          token_endpoint_auth_method: :client_secret_basic,
          logo_uri: logo_uri,
          jwks_uri: jwks_uri,
        }
      end

      specify { expect(response).to have_http_status(:created) }
      specify { expect(response.headers['Set-Cookie']).to be_nil }
      specify { expect(response.content_type).to start_with("application/json") }
      specify { expect(response.headers['Cache-Control']).to include("no-store") }
      specify { expect(response.headers['Pragma']).to eql("no-cache") }
      specify { expect(json[:client_id]).to eql(last_client.to_param) }
      specify { expect(json[:client_secret]).to be_present }
      specify { expect(json[:client_id_issued_at]).to eql(last_client.created_at.to_i) }
      specify { expect(json[:client_secret_expires_at]).to be_zero }
      specify { expect(json[:redirect_uris]).to match_array(redirect_uris) }
      specify { expect(json[:grant_types]).to match_array(last_client.grant_types.map(&:to_s)) }
      specify { expect(json[:client_name]).to eql(client_name) }
      specify { expect(json[:token_endpoint_auth_method]).to eql('client_secret_basic') }
      specify { expect(json[:logo_uri]).to eql(logo_uri) }
      specify { expect(json[:jwks_uri]).to eql(jwks_uri) }
    end

    context "when the registrations is missing valid redirect_uris" do
      before do
        post "/oauth/clients", params: {
          redirect_uris: [],
          client_name: client_name,
          token_endpoint_auth_method: :client_secret_basic,
          logo_uri: logo_uri,
          jwks_uri: jwks_uri,
        }
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql("invalid_redirect_uri") }
      specify { expect(json[:error_description]).to be_present }
    end

    context "when the registration request is missing a client name" do
      before do
        post "/oauth/clients", params: {
          redirect_uris: redirect_uris,
          client_name: "",
          token_endpoint_auth_method: :client_secret_basic,
          logo_uri: logo_uri,
          jwks_uri: jwks_uri,
        }
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql("invalid_client_metadata") }
      specify { expect(json[:error_description]).to be_present }
    end
  end

  describe "GET /oauth/clients/:id" do
    context "when the credentials are valid" do
      let(:client) { create(:client) }
      let(:access_token) { create(:access_token, subject: client, resource: "#{Oauth::Issuer.identifier}/oauth/clients") }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { get "/oauth/clients/#{client.to_param}", headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.content_type).to start_with('application/json') }
      specify { expect(response.headers['Set-Cookie']).to be_nil }
      specify { expect(json[:client_id]).to eql(client.to_param) }
      pending { expect(json[:client_secret]).to eql(client.password) }
      specify { expect(json[:client_id_issued_at]).to eql(client.created_at.to_i) }
      specify { expect(json[:client_secret_expires_at]).to be_zero }
      specify { expect(json[:redirect_uris]).to match_array(client.redirect_uris) }
      specify { expect(json[:grant_types]).to match_array(client.grant_types.map(&:to_s)) }
      specify { expect(json[:client_name]).to eql(client.name) }
      specify { expect(json[:token_endpoint_auth_method]).to eql('client_secret_basic') }
      specify { expect(json[:logo_uri]).to eql(client.logo_uri) }
      specify { expect(json[:jwks_uri]).to eql(client.jwks_uri) }
      specify { expect(json[:registration_client_uri]).to eql(oauth_client_url(client)) }
      specify { expect(json[:registration_access_token]).to be_present }
    end

    context "when one client tries to read another client" do
      let(:client) { create(:client) }
      let(:other_client) { create(:client) }
      let(:access_token) { create(:access_token, subject: client, resource: "#{Oauth::Issuer.identifier}/oauth/clients") }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { get "/oauth/clients/#{other_client.id}", headers: headers }

      specify { expect(response).to have_http_status(:forbidden) }
    end

    context "when the client id does not exist" do
      let(:client) { create(:client) }
      let(:access_token) { create(:access_token, subject: client, resource: "#{Oauth::Issuer.identifier}/oauth/clients") }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }

      before { get "/oauth/clients/#{SecureRandom.uuid}", headers: headers }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(access_token.reload).to be_revoked }
    end

    context "when an authorization header is not provided" do
      let(:client) { create(:client) }

      before { get "/oauth/clients/#{client.to_param}", headers: {} }

      specify { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe "PUT /oauth/clients/:id" do
    context "when the credentials are valid" do
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }
      let(:client) { create(:client) }
      let(:access_token) { create(:access_token, subject: client, resource: "#{Oauth::Issuer.identifier}/oauth/clients") }

      context "when the request body is valid" do
        let(:request_body) do
          {
            client_id: client.to_param,
            client_name: FFaker::Name.name,
            grant_types: [:authorization_code, :refresh_token],
            jwks_uri: generate(:uri),
            logo_uri: generate(:uri),
            redirect_uris: [generate(:uri), generate(:uri)],
            token_endpoint_auth_method: :client_secret_basic,
          }
        end

        before { put "/oauth/clients/#{client.to_param}", params: request_body, headers: headers }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.content_type).to start_with('application/json') }
        specify { expect(json[:client_id]).to eql(client.to_param) }
        # The secret is only known at registration, it is stored hashed.
        specify { expect(json).not_to have_key(:client_secret) }
        specify { expect(json[:client_id_issued_at]).to eql(client.created_at.to_i) }
        specify { expect(json[:client_secret_expires_at]).to be_zero }
        specify { expect(json[:redirect_uris]).to match_array(request_body[:redirect_uris]) }
        specify { expect(json[:grant_types]).to match_array(request_body[:grant_types].map(&:to_s)) }
        specify { expect(json[:client_name]).to eql(request_body[:client_name]) }
        specify { expect(json[:token_endpoint_auth_method]).to eql(request_body[:token_endpoint_auth_method].to_s) }
        specify { expect(json[:logo_uri]).to eql(request_body[:logo_uri]) }
        specify { expect(json[:jwks_uri]).to eql(request_body[:jwks_uri]) }

        # RFC 7592 Section 2.2
        it 'replaces the values previously associated with the client' do
          client.reload
          expect(client.name).to eql(request_body[:client_name])
          expect(client.redirect_uris).to match_array(request_body[:redirect_uris])
          expect(client.grant_types).to match_array(%w[authorization_code refresh_token])
        end

        it 'does not change the secret' do
          expect(client.reload.authenticate(client.password)).to be_truthy
        end
      end

      context "when optional fields are omitted" do
        let(:client) { create(:client, logo_uri: generate(:uri), scope: 'admin', contacts: ['a@example.com']) }
        let(:request_body) do
          { client_id: client.to_param, client_name: 'Renamed', redirect_uris: [generate(:uri)] }
        end

        before { put "/oauth/clients/#{client.to_param}", params: request_body, headers: headers }

        specify { expect(response).to have_http_status(:ok) }

        it 'treats them as deleted' do
          client.reload
          expect(client.logo_uri).to be_nil
          expect(client.scope).to be_nil
          expect(client.contacts).to be_empty
        end
      end

      context "when the client_id is not included" do
        before { put "/oauth/clients/#{client.to_param}", params: { client_name: 'x', redirect_uris: [generate(:uri)] }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(json[:error]).to eql('invalid_client_metadata') }
        specify { expect(client.reload.name).not_to eql('x') }
      end

      context "when the client_id is not the client's own" do
        before { put "/oauth/clients/#{client.to_param}", params: { client_id: SecureRandom.uuid, client_name: 'x', redirect_uris: [generate(:uri)] }, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
      end

      %w[registration_access_token registration_client_uri client_secret_expires_at client_id_issued_at].each do |field|
        context "when the request includes #{field}" do
          before do
            put "/oauth/clients/#{client.to_param}",
              params: { client_id: client.to_param, client_name: 'x', redirect_uris: [generate(:uri)], field => 'x' },
              headers: headers
          end

          specify { expect(response).to have_http_status(:bad_request) }
          specify { expect(json[:error]).to eql('invalid_client_metadata') }
          specify { expect(client.reload.name).not_to eql('x') }
        end
      end

      context "when the request includes a client_secret that does not match" do
        before do
          put "/oauth/clients/#{client.to_param}",
            params: { client_id: client.to_param, client_secret: 'chosen-by-the-client', client_name: 'x', redirect_uris: [generate(:uri)] },
            headers: headers
        end

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(client.reload.authenticate('chosen-by-the-client')).to be_falsey }
      end

      context "when the request includes the current client_secret" do
        before do
          put "/oauth/clients/#{client.to_param}",
            params: { client_id: client.to_param, client_secret: client.password, client_name: 'x', redirect_uris: [generate(:uri)] },
            headers: headers
        end

        specify { expect(response).to have_http_status(:ok) }
      end

      context "when the request body is invalid" do
        let(:request_body) do
          {
            client_id: client.to_param,
            client_name: "",
            grant_types: [:authorization_code, :refresh_token],
            jwks_uri: generate(:uri),
            logo_uri: generate(:uri),
            redirect_uris: [generate(:uri), generate(:uri)],
            token_endpoint_auth_method: :client_secret_basic,
          }
        end

        before { put "/oauth/clients/#{client.to_param}", params: request_body, headers: headers }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.content_type).to start_with('application/json') }
        specify { expect(json[:error]).to eql("invalid_client_metadata") }
        specify { expect(json[:error_description]).to eql("Name can't be blank") }
      end
    end
  end

  describe "POST /oauth/clients with jwks" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }
    let(:public_key) { JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048).public_key).export }
    let(:params) do
      { redirect_uris: [generate(:uri)], client_name: FFaker::Name.name, jwks: { keys: [public_key] } }
    end

    context "when the keys are valid" do
      before { post "/oauth/clients", params: params, as: :json }

      specify { expect(response).to have_http_status(:created) }
      specify { expect(json[:jwks][:keys][0][:kid]).to eql(public_key[:kid]) }
      specify { expect(json[:registration_client_uri]).to eql(oauth_client_url(Client.last)) }
      specify { expect(Token.claims_for(json[:registration_access_token])[:sub]).to eql(Client.last.to_param) }
    end

    context "when the token_endpoint_auth_method is omitted" do
      before { post "/oauth/clients", params: params, as: :json }

      specify { expect(json[:token_endpoint_auth_method]).to eql('client_secret_basic') }
    end

    context "when the token_endpoint_auth_method is not supported" do
      before { post "/oauth/clients", params: params.merge(token_endpoint_auth_method: 'tls_client_auth'), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql("invalid_client_metadata") }
    end

    context "when both jwks and jwks_uri are specified" do
      before { post "/oauth/clients", params: params.merge(jwks_uri: generate(:uri)), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql("invalid_client_metadata") }
    end

    context "when the keys contain private material" do
      let(:public_key) { JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048)).export(include_private: true) }

      before { post "/oauth/clients", params: params, as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql("invalid_client_metadata") }
    end
  end

  describe "DELETE /oauth/clients/:id" do
    let(:client) { create(:client) }
    let(:access_token) { create(:access_token, subject: client, audience: client, resource: "#{Oauth::Issuer.identifier}/oauth/clients") }
    let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }

    context "when the credentials are valid" do
      before { delete "/oauth/clients/#{client.to_param}", headers: headers }

      specify { expect(response).to have_http_status(:no_content) }
      specify { expect(response.body).to be_empty }
      specify { expect(Client.exists?(client.id)).to be(false) }
      specify { expect(Token.exists?(access_token.id)).to be(false) }
    end

    context "when one client tries to delete another client" do
      let(:other_client) { create(:client) }

      before { delete "/oauth/clients/#{other_client.to_param}", headers: headers }

      specify { expect(response).to have_http_status(:forbidden) }
      specify { expect(Client.exists?(other_client.id)).to be(true) }
    end

    context "when the access token has been revoked" do
      before do
        access_token.revoke!
        Rails.cache.clear
        delete "/oauth/clients/#{client.to_param}", headers: headers
      end

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(Client.exists?(client.id)).to be(true) }
    end

    context "when an authorization header is not provided" do
      before { delete "/oauth/clients/#{client.to_param}" }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(Client.exists?(client.id)).to be(true) }
    end
  end

  # RFC 7591 Section 2 and Section 3.2.2
  describe "POST /oauth/clients metadata" do
    let(:base) { { redirect_uris: [generate(:uri)], client_name: FFaker::Name.name } }

    context "when grant_types and response_types are omitted" do
      before { post "/oauth/clients", params: base, as: :json }

      specify { expect(json[:grant_types]).to eql(%w[authorization_code]) }
      specify { expect(json[:response_types]).to eql(%w[code]) }
      specify { expect(json[:token_endpoint_auth_method]).to eql('client_secret_basic') }
    end

    context "when only client_credentials is requested" do
      before { post "/oauth/clients", params: base.merge(grant_types: %w[client_credentials]), as: :json }

      specify { expect(response).to have_http_status(:created) }
      specify { expect(json[:grant_types]).to eql(%w[client_credentials]) }
      specify { expect(json[:response_types]).to be_empty }
    end

    context "when an unknown grant type is requested" do
      before { post "/oauth/clients", params: base.merge(grant_types: %w[implicit]), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_client_metadata') }
    end

    context "when the implicit response type is requested" do
      before { post "/oauth/clients", params: base.merge(grant_types: %w[authorization_code], response_types: %w[token]), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_client_metadata') }
    end

    context "when the code response type is used without the authorization_code grant" do
      before { post "/oauth/clients", params: base.merge(grant_types: %w[client_credentials], response_types: %w[code]), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
    end

    context "when a public client asks for client credentials" do
      before { post "/oauth/clients", params: base.merge(token_endpoint_auth_method: 'none', grant_types: %w[client_credentials]), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
    end

    context "when a public client is registered" do
      before { post "/oauth/clients", params: base.merge(token_endpoint_auth_method: 'none'), as: :json }

      specify { expect(response).to have_http_status(:created) }
      specify { expect(json).not_to have_key(:client_secret) }
      specify { expect(json[:token_endpoint_auth_method]).to eql('none') }
    end

    context "when the descriptive metadata is given" do
      before do
        post "/oauth/clients", as: :json, params: base.merge(
          scope: 'admin', contacts: ['ops@example.com'], client_uri: 'https://client.example.com',
          tos_uri: 'https://client.example.com/tos', policy_uri: 'https://client.example.com/policy',
          software_id: 'a-software-id', software_version: '1.2.3'
        )
      end

      specify { expect(json).to include(scope: 'admin', contacts: ['ops@example.com'], client_uri: 'https://client.example.com') }
      specify { expect(json).to include(tos_uri: 'https://client.example.com/tos', policy_uri: 'https://client.example.com/policy') }
      specify { expect(json).to include(software_id: 'a-software-id', software_version: '1.2.3') }
    end

    context "when the scope is not supported" do
      before { post "/oauth/clients", params: base.merge(scope: 'nope'), as: :json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('invalid_client_metadata') }
    end

    context "when a redirect uri has a fragment" do
      before { post "/oauth/clients", params: base.merge(redirect_uris: ['https://example.com/cb#x']), as: :json }

      specify { expect(json[:error]).to eql('invalid_redirect_uri') }
    end

    context "when a registered client uses a grant type it did not register" do
      let(:client) { create(:client, grant_types: %w[authorization_code]) }
      let(:headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) } }

      before { post '/oauth/tokens', params: { grant_type: 'client_credentials' }, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('unauthorized_client') }
    end

    context "when a client is limited to a scope" do
      let(:client) { create(:client, scope: 'admin') }
      let(:headers) { { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) } }

      before { post '/oauth/tokens', params: { grant_type: 'client_credentials', scope: 'admin' }, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
    end
  end
end
