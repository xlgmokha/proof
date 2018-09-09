require 'rails_helper'

RSpec.describe "/scim/v2/Schemas" do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user, authorization: create(:authorization, user: user)).to_jwt }
  let(:headers) do
    {
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
      'Authorization' => "Bearer #{token}"
    }
  end

  describe "GET scim/v2/Schemas" do
    before :each do
      get "/scim/v2/schemas", headers: headers
      @json = JSON.parse(response.body, symbolize_names: true)
    end

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(@json.count).to eql(2) }
    specify { expect(@json[0][:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:User') }
    specify { expect(@json[1][:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:Group') }
  end

  describe "GET /Schemas/urn:ietf:params:scim:schemas:core:2.0:User" do
    before :each do
      get "/scim/v2/schemas/urn:ietf:params:scim:schemas:core:2.0:User", headers: headers
    end
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:User') }
    specify { expect(json[:meta][:location]).to eql(scim_v2_schema_url(id: 'urn:ietf:params:scim:schemas:core:2.0:User')) }
  end

  describe "GET /Schemas/urn:ietf:params:scim:schemas:core:2.0:Group" do
    before :each do
      get "/scim/v2/schemas/urn:ietf:params:scim:schemas:core:2.0:Group", headers: headers
    end
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:Group') }
    specify { expect(json[:meta][:location]).to eql(scim_v2_schema_url(id: 'urn:ietf:params:scim:schemas:core:2.0:Group')) }
  end
end
