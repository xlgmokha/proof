require 'rails_helper'

RSpec.describe "/scim/v2/ResourceTypes" do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user, authorization: create(:authorization, user: user)).to_jwt }
  let(:headers) do
    {
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
      'Authorization' => "Bearer #{token}"
    }
  end

  describe "GET /scim/v2/ResourceTypes" do
    before { get "/scim/v2/ResourceTypes", headers: headers }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json.count).to eql(2) }
    specify { expect(json[0][:schemas]).to match_array(["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]) }
    specify { expect(json[0][:id]).to eql('User') }
    specify { expect(json[0][:name]).to eql('User') }
    specify { expect(json[0][:endpoint]).to eql(scim_v2_users_url) }
    specify { expect(json[0][:meta][:location]).to eql(scim_v2_resource_type_url(id: 'User')) }
    specify { expect(json[0][:meta][:resourceType]).to eql('ResourceType') }

    specify { expect(json[1][:schemas]).to match_array(["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]) }
    specify { expect(json[1][:id]).to eql('Group') }
    specify { expect(json[1][:name]).to eql('Group') }
    specify { expect(json[1][:schema]).to eql('urn:ietf:params:scim:schemas:core:2.0:Group') }
    specify { expect(json[1][:endpoint]).to eql(scim_v2_groups_url) }
    specify { expect(json[1][:meta][:location]).to eql(scim_v2_resource_type_url(id: 'Group')) }
    specify { expect(json[1][:meta][:resourceType]).to eql('ResourceType') }
    specify { expect(json[1][:schemaExtensions]).to match_array([]) }
  end

  describe "GET /scim/v2/ResourceTypes/User" do
    before { get "/scim/v2/ResourceTypes/User", headers: headers }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:schemas]).to match_array(["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]) }
    specify { expect(json[:id]).to eql('User') }
    specify { expect(json[:name]).to eql('User') }
    specify { expect(json[:endpoint]).to eql(scim_v2_users_url) }
    specify { expect(json[:meta][:location]).to eql(scim_v2_resource_type_url(id: 'User')) }
    specify { expect(json[:meta][:resourceType]).to eql('ResourceType') }
  end

  describe "GET /scim/v2/ResourceTypes/Group" do
    before { get "/scim/v2/ResourceTypes/Group", headers: headers }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:schemas]).to match_array(["urn:ietf:params:scim:schemas:core:2.0:ResourceType"]) }
    specify { expect(json[:id]).to eql('Group') }
    specify { expect(json[:name]).to eql('Group') }
    specify { expect(json[:endpoint]).to eql(scim_v2_groups_url) }
    specify { expect(json[:meta][:location]).to eql(scim_v2_resource_type_url(id: 'Group')) }
    specify { expect(json[:meta][:resourceType]).to eql('ResourceType') }
    specify { expect(json[:schema]).to eql('urn:ietf:params:scim:schemas:core:2.0:Group') }
    specify { expect(json[:schemaExtensions]).to match_array([]) }
  end

  describe "GET /scim/v2/ResourceTypes/unknown" do
    before { get "/scim/v2/ResourceTypes/unknown", headers: headers }

    specify { expect(response).to have_http_status(:not_found) }
  end
end
