require 'rails_helper'

RSpec.describe "/api/scim/v2/Bulk" do
  let(:user) { create(:user) }
  let(:access_token) { user.access_token('unknown') }
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
