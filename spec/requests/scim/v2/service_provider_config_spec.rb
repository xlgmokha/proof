# frozen_string_literal: true

require 'rails_helper'

describe "/ServiceProviderConfig" do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user).to_jwt }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
    }
  end

  context "when loading the service provider configuration" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get '/scim/v2/ServiceProviderConfig', headers: headers }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.body).to be_present }
    specify { expect(json[:schemas]).to match_array([Scim::Shady::Schemas::SERVICE_PROVIDER_CONFIG]) }
    specify { expect(json[:documentationUri]).to eql(root_url + "doc") }
    specify { expect(json[:patch][:supported]).to be(false) }
    specify { expect(json[:bulk][:supported]).to be(false) }
    specify { expect(json[:filter][:supported]).to be(false) }
    specify { expect(json[:changePassword][:supported]).to be(false) }
    specify { expect(json[:sort][:supported]).to be(false) }
    specify { expect(json[:etag][:supported]).to be(false) }
    specify { expect(json[:authenticationSchemes]).to match_array([name: 'OAuth Bearer Token', description: 'Authentication scheme using the OAuth Bearer Token Standard', specUri: 'http://www.rfc-editor.org/info/rfc6750', documentationUri: 'http://example.com/help/oauth.html', type: 'oauthbearertoken', primary: true]) }
    specify { expect(json[:meta][:location]).to eql(scim_v2_ServiceProviderConfig_url) }
    specify { expect(json[:meta][:resourceType]).to eql('ServiceProviderConfig') }
    specify { expect(json[:meta][:created]).to be_present }
    specify { expect(json[:meta][:lastModified]).to be_present }
    specify { expect(json[:meta][:version]).to be_present }
  end
end
