require 'rails_helper'

describe '/scim/v2/users' do
  describe "POST /scim/v2/users" do
    let(:token) { SecureRandom.uuid  }
    let(:email) { FFaker::Internet.email }
    let(:headers) do
      {
        'Authorization' => "Bearer #{token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
      }
    end

    it 'creates a new user' do
      body = { schemas: [Scim::Shady::Schemas::USER], userName: email }

      post '/scim/v2/users', params: body.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.headers['Content-Type']).to eql('application/scim+json')
      expect(response.headers['Location']).to be_present
      expect(response.body).to be_present

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Schemas::USER])
      expect(json[:id]).to be_present
      expect(json[:userName]).to eql(email)
      expect(json[:meta][:resourceType]).to eql('User')
      expect(json[:meta][:created]).to be_present
      expect(json[:meta][:lastModified]).to be_present
      expect(json[:meta][:location]).to be_present
      expect(json[:meta][:version]).to be_present
    end
  end
end
