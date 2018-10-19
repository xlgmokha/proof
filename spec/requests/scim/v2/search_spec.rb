# frozen_string_literal: true

require 'rails_helper'

describe '/scim/v1/.search' do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user).to_jwt }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
    }
  end

  describe "POST /scim/v2/.search" do
    let(:request_body) do
      {
        "schemas": [Scim::Shady::Messages::SEARCH_REQUEST],
        "attributes": %w[displayName userName],
        "filter": "displayName sw \"smith\"",
        "startIndex": 1,
        "count": 10
      }
    end
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { post "/scim/v2/.search", headers: headers, params: request_body.to_json }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
    specify { expect(response.body).to be_present }
    specify { expect(json[:schemas]).to match_array([Scim::Shady::Messages::LIST_RESPONSE]) }
    specify { expect(json[:totalResults]).to be_zero }
    specify { expect(json[:itemsPerPage]).to be_zero }
    specify { expect(json[:startIndex]).to be(1) }
    specify { expect(json[:Resources]).to be_empty }
  end
end
