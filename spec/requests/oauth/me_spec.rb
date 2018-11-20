# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/oauth/me' do
  describe "GET /oauth/me" do
    context "when the access_token is valid" do
      let(:token) { create(:access_token) }
      let(:headers) { { 'Authorization' => "Bearer #{token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }

      before { get '/oauth/me', headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response['Content-Type']).to include('application/json') }
      specify { expect(json[:sub]).to eql(token.claims[:sub]) }
      specify { expect(json[:aud]).to eql(token.claims[:aud]) }
      specify { expect(json[:iss]).to eql(token.claims[:iss]) }
      specify { expect(json[:exp]).to eql(token.claims[:exp]) }
      specify { expect(json[:iat]).to eql(token.claims[:iat]) }
    end

    context "when the token is revoked" do
      let(:headers) { { 'Authorization' => "Bearer #{token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      let(:token) { create(:access_token, :revoked) }

      before { get '/oauth/me', headers: headers }

      specify { expect(response).to have_http_status(:unauthorized) }
    end

    context "when the token is expired" do
      let(:headers) { { 'Authorization' => "Bearer #{token.to_jwt}" } }
      let(:json) { JSON.parse(response.body, symbolize_names: true) }
      let(:token) { create(:access_token, :expired) }

      before { get '/oauth/me', headers: headers }

      specify { expect(response).to have_http_status(:unauthorized) }
    end
  end
end
