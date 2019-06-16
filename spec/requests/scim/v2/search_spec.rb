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
        "schemas": [Scim::Kit::V2::Messages::SEARCH_REQUEST],
        "attributes": %w[displayName userName],
        "filter": "userName sw \"#{user.email}\"",
        "startIndex": 1,
        "count": 10
      }
    end
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { post "/scim/v2/.search", headers: headers, params: request_body.to_json }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
    specify { expect(response.body).to be_present }
    specify { expect(json[:schemas]).to match_array([Scim::Kit::V2::Messages::LIST_RESPONSE]) }
    specify { expect(json[:totalResults]).to be(1) }
    specify { expect(json[:itemsPerPage]).to be(10) }
    specify { expect(json[:startIndex]).to be(1) }
    specify { expect(json[:Resources].map { |x| x[:userName] }).to match_array([user.email]) }
    specify { expect(json[:Resources].map { |x| x[:displayName] }).to match_array([user.email]) }
  end
end
