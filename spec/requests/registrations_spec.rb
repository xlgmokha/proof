# frozen_string_literal: true

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
      let(:new_password) { FFaker::Internet.password }

      before { post "/registrations", params: { user: { email: email, password: new_password, password_confirmation: new_password } } }

      specify { expect(response).to redirect_to(new_session_url) }
      specify { expect(User.count).to be(1) }
      specify { expect(User.last.email).to eql(email) }
    end

    context "when the new registration data is invalid" do
      let(:user) { create(:user) }

      before { post "/registrations", params: { user: { email: user.email, password: "password" } } }

      specify { expect(response).to redirect_to(new_registration_path) }
      specify { expect(flash[:error]).to be_present }
    end

    context "when the password confirmation does not match" do
      let(:email) { FFaker::Internet.email }
      let(:new_password) { FFaker::Internet.password }

      before { post "/registrations", params: { user: { email: email, password: new_password, password_confirmation: 'other' } } }

      specify { expect(response).to redirect_to(new_registration_path) }
      specify { expect(flash[:error]).to be_present }
    end
  end
end
