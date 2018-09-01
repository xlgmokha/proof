require 'rails_helper'

RSpec.describe RegistrationsController do
  describe "#new" do
    it 'renders a registration page' do
      get '/registrations/new'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Register")
    end
  end

  describe "#create" do
    let(:email) { FFaker::Internet.email }

    it 'registers a new user' do
      post "/registrations", params: { user: { email: email, password: "password" } }

      expect(response).to redirect_to(new_session_url)
      expect(User.count).to eql(1)
      expect(User.last.email).to eql(email)
    end
  end
end
