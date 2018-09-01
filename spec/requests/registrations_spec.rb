require 'rails_helper'

RSpec.describe '/registrations' do
  describe "GET /registrations/new" do
    before { get '/registrations/new' }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.body).to include("Register") }
  end

  describe "POST /registrations" do
    context "when the new registration data is valid" do
      let(:email) { FFaker::Internet.email }
      before { post "/registrations", params: { user: { email: email, password: "password" } } }

      specify { expect(response).to redirect_to(new_session_url) }
      specify { expect(User.count).to eql(1) }
      specify { expect(User.last.email).to eql(email) }
    end

    context "when the new registration data is invalid" do
      let(:user) { create(:user) }
      let(:email) { user.email }

      before { post "/registrations", params: { user: { email: email, password: "password" } } }

      specify { expect(response).to redirect_to(new_registration_path) }
      specify { expect(flash[:error]).to be_present }
    end
  end
end
