require 'rails_helper'

RSpec.describe '/oauth' do
  context "when the user is logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /oauth/:client_id" do
      context "when the client id is known" do
        let(:client) { create(:client) }
        before { get "/oauth/#{client.to_param}" }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include(client.name) }
      end
    end

    describe "POST /oauth" do
      context "when the client id is known" do
        let(:client) { create(:client) }
        before { post "/oauth", params: { client_id: client.to_param } }

        specify { expect(response).to redirect_to(client.redirect_uri_path(code: Authorization.last.code)) }
      end
    end
  end
end
