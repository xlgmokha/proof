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

  it 'returns a 200' do
    get '/scim/v2/ServiceProviderConfig', headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to be_present

    json = JSON.parse(response.body, symbolize_names: true)
    expect(json[:schemas]).to match_array([Scim::Shady::Schemas::SERVICE_PROVIDER_CONFIG])
    expect(json[:documentationUri]).to be_blank
    expect(json[:patch][:supported]).to be(false)
    expect(json[:bulk][:supported]).to be(false)
    expect(json[:filter][:supported]).to be(false)
    expect(json[:changePassword][:supported]).to be(false)
    expect(json[:sort][:supported]).to be(false)
    expect(json[:etag][:supported]).to be(false)
    expect(json[:authenticationSchemes]).to match_array([
      name: 'OAuth Bearer Token',
      description: 'Authentication scheme using the OAuth Bearer Token Standard',
      specUri: 'http://www.rfc-editor.org/info/rfc6750',
      documentationUri: 'http://example.com/help/oauth.html',
      type: 'oauthbearertoken',
      primary: true,
    ])
    expect(json[:meta][:location]).to eql(scim_v2_ServiceProviderConfig_url)
    expect(json[:meta][:resourceType]).to eql('ServiceProviderConfig')
    expect(json[:meta][:created]).to be_present
    expect(json[:meta][:lastModified]).to be_present
    expect(json[:meta][:version]).to be_present
  end
end
