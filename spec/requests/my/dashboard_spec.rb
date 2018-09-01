require 'rails_helper'

RSpec.describe "/my/dashboard" do
  context "when logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /my/dashboard" do
      before { get '/my/dashboard' }

      specify { expect(response).to have_http_status(:ok) }
    end
  end

  context "when not logged in" do
    before { get '/my/dashboard' }

    specify { expect(response).to redirect_to(new_session_path) }
  end
end
