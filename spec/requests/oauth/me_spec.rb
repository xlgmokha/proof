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

    # RFC 6750 Section 3
    context "when no credentials are presented" do
      before { get '/oauth/me' }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to eql('Bearer realm="oauth"') }
    end

    context "when the access token is invalid" do
      before { get '/oauth/me', headers: { 'Authorization' => 'Bearer nope' } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to start_with('Bearer realm="oauth", error="invalid_token"') }
    end

    context "when a refresh token is presented as an access token" do
      before { get '/oauth/me', headers: { 'Authorization' => "Bearer #{create(:refresh_token).to_jwt}" } }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(response.headers['WWW-Authenticate']).to include('error="invalid_token"') }
    end

    context "when the scheme is lowercase" do
      before { get '/oauth/me', headers: { 'Authorization' => "bearer #{create(:access_token).to_jwt}" } }

      specify { expect(response).to have_http_status(:ok) }
    end

    context "when the token is sent as a form-encoded body parameter" do
      before { post '/oauth/me', params: { access_token: create(:access_token).to_jwt } }

      specify { expect(response).to have_http_status(:ok) }
    end

    context "when the token was authorized without the required scope" do
      before do
        allow_any_instance_of(Oauth::MesController).to receive(:required_scope).and_return('other') # rubocop:disable RSpec/AnyInstance
        get '/oauth/me', headers: { 'Authorization' => "Bearer #{create(:access_token, scope: 'admin').to_jwt}" }
      end

      specify { expect(response).to have_http_status(:forbidden) }
      specify { expect(response.headers['WWW-Authenticate']).to include('error="insufficient_scope"', 'scope="other"') }
    end

    context "when two methods are used at once" do
      before do
        token = create(:access_token).to_jwt
        post '/oauth/me', params: { access_token: token }, headers: { 'Authorization' => "Bearer #{token}" }
      end

      specify { expect(response).to have_http_status(:bad_request) }
    end
  end
end
