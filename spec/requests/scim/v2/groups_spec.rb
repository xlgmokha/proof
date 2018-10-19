# frozen_string_literal: true

require 'rails_helper'

describe "/scim/v2/groups" do
  context "when authenticated" do
    let(:user) { create(:user) }
    let(:token) { create(:access_token, subject: user) }
    let(:headers) do
      {
        'Authorization' => "Bearer #{token.to_jwt}",
        'Accept' => 'application/scim+json',
        'Content-Type' => 'application/scim+json',
      }
    end

    describe "GET /scim/v2/groups" do
      before { get '/scim/v2/groups', headers: headers }

      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
      specify { expect(response.body).to be_present }

      specify { expect(json[:schemas]).to match_array([Scim::Shady::Messages::LIST_RESPONSE]) }
      specify { expect(json[:totalResults]).to be_kind_of(Numeric) }
      specify { expect(json[:Resources]).to match_array([id: user.uuid, userName: user.email]) }
    end
  end

  context "when the authentication token is invalid" do
    let(:bad_headers) do
      {
        'Authorization' => "Bearer #{SecureRandom.uuid}",
        'Accept' => 'application/scim+json',
        'Content-Type' => 'application/scim+json',
      }
    end

    before { get '/scim/v2/groups', headers: bad_headers }

    specify { expect(response).to have_http_status(:unauthorized) }
  end
end
