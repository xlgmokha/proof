require 'rails_helper'

describe "/scim/v2/groups" do
  context "when authenticated" do
    let(:user) { create(:user) }
    let(:token) { user.access_token('unknown') }
    let(:headers) do
      {
        'Authorization' => "Bearer #{token}",
        'Accept' => 'application/scim+json',
        'Content-Type' => 'application/scim+json',
      }
    end

    describe "GET /scim/v2/groups" do
      before { get '/scim/v2/groups', headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
      specify { expect(response.body).to be_present }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      specify { expect(json[:schemas]).to match_array([Scim::Shady::Messages::LIST_RESPONSE]) }
      specify { expect(json[:totalResults]).to eql(1) }
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
