require 'rails_helper'

RSpec.describe '/oauth' do
  context "when the user is logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /oauth" do
      let(:state) { SecureRandom.uuid  }

      context "when the client id is known" do
        let(:client) { create(:client) }

        context "when requesting an authorization code" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'code', state: state } }
          specify { expect(response).to have_http_status(:ok) }
          specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
        end

        context "when requesting an access token" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'token', state: state } }
          specify { expect(response).to have_http_status(:ok) }
          specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
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
        specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
      end
    end

    describe "POST /oauth" do
      context "when the client id is known" do
        let(:client) { create(:client) }
        let(:state) { SecureRandom.uuid }

        context "when the client requested an authorization code" do
          before :each do
            get "/oauth", params: { client_id: client.to_param, response_type: 'code', state: state }
            post "/oauth"
          end

          specify { expect(response).to redirect_to(client.redirect_uri_path(code: Authorization.last.code, state: state)) }
        end

        context "when the client requested a token" do
          let(:token) { Token.access.active.last&.to_jwt }
          let(:scope) { "admin" }

          before :each do
            get "/oauth", params: { client_id: client.to_param, response_type: 'token', state: state }
            post "/oauth"
          end

          specify do
            expected_url = "#{client.redirect_uri}#access_token=#{token}&token_type=Bearer&expires_in=300&scope=#{scope}&state=#{state}"
            expect(response).to redirect_to(expected_url)
          end
        end
      end
    end
  end
end
