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
      specify { expect(response.content_type).to eql("application/json") }
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
      let(:access_token) { create(:access_token, subject: client) }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { get "/oauth/clients/#{client.to_param}", headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.content_type).to eql('application/json') }
      specify { expect(response.headers['Set-Cookie']).to be_nil }
      specify { expect(json[:client_id]).to eql(client.to_param) }
      specify { expect(json[:client_secret]).to eql(client.password) }
      specify { expect(json[:client_id_issued_at]).to eql(client.created_at.to_i) }
      specify { expect(json[:client_secret_expires_at]).to be_zero }
      specify { expect(json[:redirect_uris]).to match_array(client.redirect_uris) }
      specify { expect(json[:grant_types]).to match_array(client.grant_types.map(&:to_s)) }
      specify { expect(json[:client_name]).to eql(client.name) }
      specify { expect(json[:token_endpoint_auth_method]).to eql('client_secret_basic') }
      specify { expect(json[:logo_uri]).to eql(client.logo_uri) }
      specify { expect(json[:jwks_uri]).to eql(client.jwks_uri) }
      xspecify { expect(json[:registration_access_token]).to be_present }
    end

    context "when one client tries to read another client" do
      let(:client) { create(:client) }
      let(:other_client) { create(:client) }
      let(:access_token) { create(:access_token, subject: client) }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { get "/oauth/clients/#{other_client.id}", headers: headers }

      specify { expect(response).to have_http_status(:forbidden) }
    end

    context "when the client id does not exist" do
      let(:client) { create(:client) }
      let(:access_token) { create(:access_token, subject: client) }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.to_jwt}" } }

      before { get "/oauth/clients/#{SecureRandom.uuid}", headers: headers }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(access_token.reload).to be_revoked }
    end
  end
end
