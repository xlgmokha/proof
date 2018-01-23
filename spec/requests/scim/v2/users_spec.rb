require 'rails_helper'

describe '/scim/v2/users' do
  let(:token) { SecureRandom.uuid }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
    }
  end

  describe "POST /scim/v2/users" do
    let(:email) { FFaker::Internet.email }

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
      expect(json[:meta][:version]).to be_present
      expect(json[:meta][:location]).to be_present
    end
  end

  describe "GET /scim/v2/users/:id" do
    let(:user) { create(:user) }

    it 'returns the requested resource' do
      get "/scim/v2/users/#{user.uuid}"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eql('application/scim+json')
      expect(response.headers['Location']).to be_present
      expect(response.body).to be_present

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Schemas::USER])
      expect(json[:id]).to eql(user.uuid)
      expect(json[:userName]).to eql(user.email)
      expect(json[:meta][:resourceType]).to eql('User')
      expect(json[:meta][:created]).to eql(user.created_at.iso8601)
      expect(json[:meta][:lastModified]).to eql(user.updated_at.iso8601)
      expect(json[:meta][:version]).to eql(user.lock_version)
      expect(json[:meta][:location]).to eql(scim_v2_users_url(user))
    end
  end

  describe "GET /scim/v2/users" do
    it 'returns an empty set of results' do
      get "/scim/v2/users?attributes=userName"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eql('application/scim+json')
      expect(response.body).to be_present

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Messages::LIST])
      expect(json[:totalResults]).to be_zero
      expect(json[:Resources]).to be_empty
    end
  end
end
