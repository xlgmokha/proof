# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/my/clients' do
  context "when logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /my/clients" do
      before { get '/my/clients' }

      specify { expect(response).to have_http_status(:ok) }
    end

    describe "GET /my/clients/new" do
      before { get '/my/clients/new' }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.body).to include('Client Id') }
      specify { expect(response.body).to include('Secret') }
    end

    describe "POST /my/clients" do
      context "when the request data is valid" do
        let(:attributes) { attributes_for(:client) }

        before { post '/my/clients', params: { client: attributes } }

        specify { expect(response).to redirect_to(my_clients_path) }
        specify { expect(flash[:notice]).to include('success') }
        specify { expect(Client.count).to be(1) }
      end
    end
  end
end
