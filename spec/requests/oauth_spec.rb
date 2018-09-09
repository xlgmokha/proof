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
    context "when exchanging a code for a token" do
      context "when the code is still valid" do
        let(:authorization) { create(:authorization, client: client, user: user) }
        let(:client) { create(:client) }
        let(:user) { create(:user) }
        let(:code) { authorization.code }

        before { post '/oauth/token', params: { grant_type: 'authorization_code', code: code } }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:access_token]).to be_present }
        specify { expect(json[:token_type]).to be_present }
        specify { expect(json[:expires_in]).to be_present }
        specify { expect(json[:refresh_token]).to be_present }
        specify { expect(authorization.reload).to be_revoked }
      end

      context "when the code is not known" do
        before { post '/oauth/token', params: { grant_type: 'authorization_code', code: SecureRandom.hex(20) } }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.headers['Content-Type']).to include('application/json') }
        specify { expect(response.headers['Cache-Control']).to include('no-store') }
        specify { expect(response.headers['Pragma']).to eql('no-cache') }

        let(:json) { JSON.parse(response.body, symbolize_names: true) }
        specify { expect(json[:error]).to eql('invalid_request') }
      end
    end
  end
end
