require 'rails_helper'

describe '/scim/v1/.search' do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user, authorization: create(:authorization, user: user)).to_jwt }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
    }
  end

  describe "POST /scim/v2/.search" do
    it 'returns an empty set of results' do
      body = {
        "schemas": [Scim::Shady::Messages::SEARCH_REQUEST],
        "attributes": ["displayName", "userName"],
        "filter": "displayName sw \"smith\"",
        "startIndex": 1,
        "count": 10
      }
      post "/scim/v2/.search", headers: headers, params: body.to_json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eql('application/scim+json')
      expect(response.body).to be_present

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Messages::LIST_RESPONSE])
      expect(json[:totalResults]).to be_zero
      expect(json[:itemsPerPage]).to be_zero
      expect(json[:startIndex]).to eql(1)
      expect(json[:Resources]).to be_empty
    end
  end
end
