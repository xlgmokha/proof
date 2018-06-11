require 'rails_helper'

describe '/scim/v2/users' do
  let(:user) { create(:user) }
  let(:token) { user.access_token("rspec") }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
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
      get "/scim/v2/users/#{user.uuid}", headers: headers

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
      get "/scim/v2/users?attributes=userName", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eql('application/scim+json')
      expect(response.body).to be_present

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Messages::LIST_RESPONSE])
      expect(json[:totalResults]).to be_zero
      expect(json[:Resources]).to be_empty
    end
  end

  describe "PUT /scim/v2/users" do
    let(:user) { create(:user) }
    let(:new_email) { FFaker::Internet.email }

    it 'updates the user' do
      body = { schemas: [Scim::Shady::Schemas::USER], userName: new_email }
      put "/scim/v2/users/#{user.uuid}", headers: headers, params: body.to_json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eql('application/scim+json')
      expect(response.headers['Location']).to eql(scim_v2_users_url(user))
      expect(response.body).to be_present

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Schemas::USER])
      expect(json[:id]).to be_present
      expect(json[:userName]).to eql(new_email)
      expect(json[:meta][:resourceType]).to eql('User')
      expect(json[:meta][:created]).to be_present
      expect(json[:meta][:lastModified]).to be_present
      expect(json[:meta][:version]).to be_present
      expect(json[:meta][:location]).to be_present
      expect(json[:emails]).to match_array([value: new_email, type: 'work', primary: true])
    end
  end

  describe "DELETE /scim/v2/users/:id" do
    let(:other_user) { create(:user) }

    it 'deletes the user' do
      delete "/scim/v2/users/#{other_user.uuid}", headers: headers
      expect(response).to have_http_status(:no_content)

      get "/scim/v2/users/#{other_user.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_present
      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:schemas]).to match_array([Scim::Shady::Messages::ERROR])
      expect(json[:detail]).to eql("Resource #{other_user.uuid} not found")
      expect(json[:status]).to eql("404")
    end
  end
end
