# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/scim/v2/Schemas" do
  let(:headers) do
    {
      'Accept' => Mime[:scim].to_s,
      'Content-Type' => Mime[:scim].to_s,
    }
  end

  describe "GET scim/v2/Schemas" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get "/scim/v2/schemas", headers: headers }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json.count).to be(2) }
    specify { expect(json[0][:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:User') }
    specify { expect(json[1][:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:Group') }
  end

  describe "GET /Schemas/urn:ietf:params:scim:schemas:core:2.0:User" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get "/scim/v2/schemas/urn:ietf:params:scim:schemas:core:2.0:User", headers: headers }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:User') }
    specify { expect(json[:meta][:location]).to eql(scim_v2_schema_url(id: 'urn:ietf:params:scim:schemas:core:2.0:User')) }
  end

  describe "GET /Schemas/urn:ietf:params:scim:schemas:core:2.0:Group" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get "/scim/v2/schemas/urn:ietf:params:scim:schemas:core:2.0:Group", headers: headers }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:id]).to eql('urn:ietf:params:scim:schemas:core:2.0:Group') }
    specify { expect(json[:meta][:location]).to eql(scim_v2_schema_url(id: 'urn:ietf:params:scim:schemas:core:2.0:Group')) }
  end
end
