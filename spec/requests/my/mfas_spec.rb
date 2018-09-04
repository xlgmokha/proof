require 'rails_helper'

RSpec.describe '/my/mfa' do
  context "when logged in" do
    let(:current_user) { create(:user) }
    before { http_login(current_user) }

    describe "GET /my/mfa" do
      context "when MFA is set up" do
        let(:current_user) { create(:user, :mfa_configured) }

        before { get '/my/mfa' }
        specify { expect(response).to redirect_to(edit_my_mfa_path) }
      end

      context "when MFA is not set up" do
        before { get '/my/mfa' }
        specify { expect(response).to redirect_to(new_my_mfa_path) }
      end
    end

    describe "GET /my/mfa/new" do
      context "when mfa has not been set up yet" do
        before { get '/my/mfa/new' }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include('Provisioning URI') }
      end

      context "when mfa has been set up" do
        let(:current_user) { create(:user, :mfa_configured) }
        before { get '/my/mfa/new' }

        specify { expect(response).to redirect_to(edit_my_mfa_path) }
      end
    end

    describe "POST /my/mfa" do
      context "when the secret is valid" do
        let(:secret) { SecureRandom.hex(20) }
        before { post '/my/mfa', params: { user: { tfa_secret: secret } } }

        specify { expect(current_user.reload.tfa_secret).to eql(secret) }
        specify { expect(response).to redirect_to(my_dashboard_path) }
        specify { expect(flash[:notice]).to include("successfully updated!") }
      end
    end

    describe "DELETE /my/mfa" do
      context "when mfa is enabled" do
        let(:current_user) { create(:user, :mfa_configured) }

        before { delete '/my/mfa' }

        specify { expect(current_user.reload.tfa_secret).to be_nil }
        specify { expect(response).to redirect_to(my_dashboard_path) }
        specify { expect(flash[:notice]).to include("MFA has been disabled") }
      end
    end
  end

  context "when not logged in" do
    before { get '/my/mfa/new' }

    specify { expect(response).to redirect_to(new_session_path) }
  end
end
