require 'rails_helper'

RSpec.describe "/my/sessions" do
  describe "when logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /my/sessions" do
      let!(:active_session) { create(:user_session, user: current_user) }

      before { get '/my/sessions' }

      specify { expect(response.body).to include(active_session.user_agent) }
    end
  end
end
