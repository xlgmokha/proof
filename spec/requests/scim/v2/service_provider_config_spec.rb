require 'rails_helper'

describe "/ServiceProviderConfig" do
  it 'returns a 200' do
    get '/scim/v2/ServiceProviderConfig'

    expect(response).to have_http_status(:ok)
    expect(response.body).to be_present

    json = JSON.parse(response.body, symbolize_names: true)
    expect(json[:schemas]).to match_array([Scim::Shady::Schemas::SERVICE_PROVIDER_CONFIG])
  end
end
