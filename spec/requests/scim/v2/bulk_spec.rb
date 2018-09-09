require 'rails_helper'

RSpec.describe "/api/scim/v2/Bulk" do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user, authorization: create(:authorization, user: user)).to_jwt }
  let(:headers) do
    {
      'Authorization' => "Bearer #{access_token}",
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
    }
  end

  describe "POST /scim/v2/Bulk" do
    before { post '/scim/v2/Bulk' }
    specify { expect(response).to have_http_status(:not_implemented) }
  end
end
