require 'rails_helper'

RSpec.describe "/mfa" do
  context "when username/password entry has been completed" do
    let(:current_user) { create(:user, :mfa_configured) }

    before { http_login(current_user) }

    describe "GET /mfa/new" do
      before { get '/mfa/new' }

      specify { expect(response).to have_http_status(:ok) }
    end

    describe "POST /mfa" do
      context "when the code is correct" do
        let(:correct_code) { current_user.tfa.current_totp }
        before { post '/mfa', params: { mfa: { code: correct_code } } }

        specify { expect(response).to redirect_to(response_path) }
        specify { expect(session[:mfa]).to be_present }
      end

      context "when the code is incorrect" do
        let(:incorrect_code) { rand(1_000) }
        before { post '/mfa', params: { mfa: { code: incorrect_code } } }

        specify { expect(response).to redirect_to(new_mfa_path) }
        specify { expect(flash[:error]).to be_present }
      end
    end
  end

  context "when username/password entry has not been completed" do
    describe "GET /mfa/new" do
      before { get '/mfa/new' }

      specify { expect(response).to redirect_to(new_session_path) }
    end
  end
end
