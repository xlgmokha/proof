# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/oauth' do
  context "when the user is logged in" do
    let(:current_user) { create(:user) }

    before { http_login(current_user) }

    describe "GET /oauth" do
      let(:state) { SecureRandom.uuid }

      context "when the client id is known" do
        let(:client) { create(:client) }

        context "when requesting an authorization code" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'code', state: state, redirect_uri: client.redirect_uris[0] } }

          specify { expect(response).to have_http_status(:ok) }
          specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
        end

        context "when requesting an access token" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'token', state: state, redirect_uri: client.redirect_uris[0] } }

          specify { expect(response).to have_http_status(:ok) }
          specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
        end

        context "when an incorrect response_type is provided" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'invalid', redirect_uri: client.redirect_uris[0] } }

          specify { expect(response).to redirect_to("#{client.redirect_uris[0]}#error=unsupported_response_type") }
        end

        context "when the redirect uri does not match" do
          before { get "/oauth", params: { client_id: client.to_param, response_type: 'invalid', redirect_uri: SecureRandom.uuid } }

          specify { expect(response).to redirect_to("#{client.redirect_uris[0]}#error=invalid_request") }
        end
      end
    end

    describe "GET /oauth/authorize" do
      let(:state) { SecureRandom.uuid }

      context "when the client id is known" do
        let(:client) { create(:client) }

        before { get "/oauth/authorize", params: { client_id: client.to_param, response_type: 'code', state: state, redirect_uri: client.redirect_uris[0] } }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
      end
    end

    describe "POST /oauth" do
      context "when the client id is known" do
        let(:client) { create(:client) }
        let(:state) { SecureRandom.uuid }

        context "when the client requested an authorization code" do
          before do
            get "/oauth", params: { client_id: client.to_param, response_type: 'code', state: state, redirect_uri: client.redirect_uris[0] }
            post "/oauth"
          end

          specify { expect(response).to redirect_to(client.redirect_url(code: Authorization.last.code, state: state)) }
        end

        context "when the client requested a token" do
          let(:token) { Token.access.active.last&.to_jwt }
          let(:scope) { "admin" }

          before do
            get "/oauth", params: { client_id: client.to_param, response_type: 'token', state: state, redirect_uri: client.redirect_uris[0] }
            post "/oauth"
          end

          specify { expect(response).to redirect_to("#{client.redirect_uris[0]}#access_token=#{token}&token_type=Bearer&expires_in=300&scope=#{scope}&state=#{state}") }
        end

        context "when the client requested a token using a valid PKCE with S256" do
          let(:token) { Token.access.active.last&.to_jwt }
          let(:code_verifier) { SecureRandom.hex(128) }
          let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.hexdigest(code_verifier)) }

          before do
            get "/oauth", params: {
              client_id: client.to_param,
              response_type: 'code',
              code_challenge: code_challenge,
              code_challenge_method: 'S256',
              state: state,
              redirect_uri: client.redirect_uris[0]
            }
            post "/oauth"
          end

          specify { expect(response).to redirect_to(client.redirect_url(code: Authorization.last.code, state: state)) }
          specify { expect(Authorization.last).to be_sha256 }
          specify { expect(Authorization.last.challenge).to eql(code_challenge) }
        end

        context "when the client requested a token using a valid PKCE with plain" do
          let(:token) { Token.access.active.last&.to_jwt }
          let(:code_verifier) { SecureRandom.hex(128) }

          before do
            get "/oauth", params: {
              client_id: client.to_param,
              response_type: 'code',
              code_challenge: code_verifier,
              code_challenge_method: 'plain',
              state: state,
              redirect_uri: client.redirect_uris[0]
            }
            post "/oauth"
          end

          specify { expect(response).to redirect_to(client.redirect_url(code: Authorization.last.code, state: state)) }
          specify { expect(Authorization.last).to be_plain }
          specify { expect(Authorization.last.challenge).to eql(code_verifier) }
        end

        context "when the client requested a token using a valid PKCE with the default code_challenge_method" do
          let(:token) { Token.access.active.last&.to_jwt }
          let(:code_verifier) { SecureRandom.hex(128) }

          before do
            get "/oauth", params: {
              client_id: client.to_param,
              response_type: 'code',
              code_challenge: code_verifier,
              state: state,
              redirect_uri: client.redirect_uris[0]
            }
            post "/oauth"
          end

          specify { expect(response).to redirect_to(client.redirect_url(code: Authorization.last.code, state: state)) }
          specify { expect(Authorization.last).to be_plain }
          specify { expect(Authorization.last.challenge).to eql(code_verifier) }
        end

        context "when the client did not make an appropriate request" do
          before { post "/oauth" }

          specify { expect(response).to have_http_status(:bad_request) }
        end

        context "when the state parameter looks malicious" do
          let(:state) { "<script>alert('hi');</script>" }

          before do
            get "/oauth", params: { client_id: client.to_param, response_type: 'token', state: state, redirect_uri: client.redirect_uris[0] }
            post "/oauth"
          end

          specify { expect(response).to redirect_to(client.redirect_url(error: 'invalid_request')) }
        end
      end
    end
  end
end
