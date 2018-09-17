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
        let(:authorization) { create(:authorization) }

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
        let(:authorization) { create(:authorization, expired_at: 1.second.ago) }

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
  end
end
