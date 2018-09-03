require 'rails_helper'

RSpec.describe "/mfa" do
  context "when username/password entry has been completed" do
    let(:current_user) { create(:user, :mfa_configured) }

    before { http_login(current_user) }

    describe "GET /mfa/new" do
      before { get '/mfa/new' }

      specify { expect(response).to have_http_status(:ok) }
    end
  end

  context "when username/password entry has not been completed" do
    before { get '/mfa/new' }

    specify { expect(response).to redirect_to(new_session_path) }
  end
end
