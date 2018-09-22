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
          specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
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
end
