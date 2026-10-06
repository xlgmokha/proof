# frozen_string_literal: true

RSpec.shared_context 'with scim authentication' do
  let(:user) { create(:user) }
  let(:token) { create(:access_token, subject: user).to_jwt }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/scim+json',
      'Content-Type' => 'application/scim+json',
    }
  end
  let(:json) { JSON.parse(response.body, symbolize_names: true) }
  let(:patch_schema) { Scim::Kit::V2::Messages::PATCH_OP }

  def patch_body(*operations)
    { schemas: [patch_schema], Operations: operations }.to_json
  end
end
