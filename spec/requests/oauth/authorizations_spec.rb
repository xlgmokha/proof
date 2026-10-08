# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/oauth/authorizations' do
  context "when the user is logged in" do
    let(:current_user) { create(:user) }
    let(:client) { create(:client) }
    let(:redirect_uri) { client.redirect_uris[0] }
    let(:state) { SecureRandom.uuid }
    let(:params) do
      {
        client_id: client.to_param, response_type: 'code', state: state, redirect_uri: redirect_uri,
        code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
      }
    end

    def query_of(url)
      Rack::Utils.parse_query(URI.parse(url).query)
    end

    before { http_login(current_user) }

    describe "GET /oauth/authorizations" do
      context "when requesting an authorization code" do
        before { get "/oauth/authorizations", params: params }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
      end

      context "when the client id is not known" do
        before { get "/oauth/authorizations", params: params.merge(client_id: SecureRandom.uuid) }

        # RFC 6749 Section 4.1.2.1: never redirect to an untrusted location.
        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.location).to be_nil }
      end

      context "when the redirect uri is not registered" do
        before { get "/oauth/authorizations", params: params.merge(redirect_uri: 'https://evil.example.com/cb') }

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(response.location).to be_nil }
      end

      context "when the redirect uri only differs by a trailing path" do
        before { get "/oauth/authorizations", params: params.merge(redirect_uri: "#{redirect_uri}/more") }

        # RFC 9700 Section 4.1.3: exact string matching.
        specify { expect(response).to have_http_status(:bad_request) }
      end

      context "when the redirect uri is omitted and one is registered" do
        before { get "/oauth/authorizations", params: params.except(:redirect_uri) }

        specify { expect(response).to have_http_status(:ok) }
      end

      context "when the redirect uri is omitted and several are registered" do
        let(:client) { create(:client, redirect_uris: ['https://a.example.com/cb', 'https://b.example.com/cb']) }

        before { get "/oauth/authorizations", params: params.except(:redirect_uri) }

        specify { expect(response).to have_http_status(:bad_request) }
      end

      context "when a loopback redirect is registered" do
        let(:client) { create(:client, redirect_uris: ['http://127.0.0.1/callback']) }

        before { get "/oauth/authorizations", params: params.merge(redirect_uri: 'http://127.0.0.1:51234/callback') }

        # RFC 8252 Section 7.3: the port of a loopback redirect may vary.
        specify { expect(response).to have_http_status(:ok) }
      end

      context "when an incorrect response_type is provided" do
        before { get "/oauth/authorizations", params: params.merge(response_type: 'invalid') }

        let(:query) { query_of(response.location) }

        specify { expect(response.location).to start_with("#{redirect_uri}?") }
        specify { expect(query['error']).to eql('unsupported_response_type') }
        specify { expect(query['state']).to eql(state) }
        specify { expect(query['iss']).to eql(Oauth::Issuer.identifier) }
        specify { expect(URI.parse(response.location).fragment).to be_nil }
      end

      context "when the implicit grant is requested" do
        before { get "/oauth/authorizations", params: params.merge(response_type: 'token') }

        # RFC 9700 Section 2.1.2
        specify { expect(query_of(response.location)['error']).to eql('unsupported_response_type') }
      end

      context "when the response_type is missing" do
        before { get "/oauth/authorizations", params: params.except(:response_type) }

        # RFC 6749 Section 4.1.2.1: a missing parameter is invalid_request.
        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when the code_challenge is missing" do
        before { get "/oauth/authorizations", params: params.except(:code_challenge, :code_challenge_method) }

        # RFC 7636 / RFC 9700 Section 2.1.1
        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
        specify { expect(query_of(response.location)['error_description']).to include('code_challenge') }
      end

      context "when the code_challenge_method is not supported" do
        before { get "/oauth/authorizations", params: params.merge(code_challenge_method: 'S512') }

        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when the code_challenge_method is plain" do
        before { get "/oauth/authorizations", params: params.merge(code_challenge_method: 'plain') }

        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when the code_challenge_method is omitted" do
        before { get "/oauth/authorizations", params: params.except(:code_challenge_method) }

        # RFC 7636 Section 4.3 defaults to plain, which is not accepted.
        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when the code_challenge is malformed" do
        before { get "/oauth/authorizations", params: params.merge(code_challenge: 'abc') }

        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when the code_challenge is sent as an array" do
        before { get "/oauth/authorizations", params: params.merge(code_challenge: ['x']) }

        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when the code_challenge is not 43 characters" do
        before { get "/oauth/authorizations", params: params.merge(code_challenge: 'a' * 100) }

        specify { expect(query_of(response.location)['error']).to eql('invalid_request') }
      end

      context "when a loopback redirect carries a fragment or userinfo" do
        let(:client) { create(:client, redirect_uris: ['http://127.0.0.1/callback']) }

        ['http://127.0.0.1:99/callback#frag', 'http://u:p@127.0.0.1:99/callback'].each do |uri|
          it "rejects #{uri}" do
            get "/oauth/authorizations", params: params.merge(redirect_uri: uri)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context "when the scope is not supported" do
        before { get "/oauth/authorizations", params: params.merge(scope: 'admin nope') }

        specify { expect(query_of(response.location)['error']).to eql('invalid_scope') }
      end

      context "when the redirect uri already has a query" do
        let(:client) { create(:client, redirect_uris: ['https://example.com/cb?tenant=1']) }

        before { get "/oauth/authorizations", params: params.merge(response_type: 'nope') }

        # RFC 6749 Section 3.1.2: the query component must be retained.
        specify { expect(query_of(response.location)).to include('tenant' => '1', 'error' => 'unsupported_response_type') }
      end
    end

    describe "POST /oauth/authorizations" do
      let(:query) { query_of(response.location) }
      let(:authorization) { Authorization.last }

      context "when the user approves the request" do
        before do
          get "/oauth/authorizations", params: params
          post "/oauth/authorizations"
        end

        specify { expect(response.location).to start_with("#{redirect_uri}?") }
        specify { expect(query['code']).to eql(authorization.code) }
        specify { expect(query['state']).to eql(state) }
        # RFC 9207
        specify { expect(query['iss']).to eql(Oauth::Issuer.identifier) }
        specify { expect(URI.parse(response.location).fragment).to be_nil }
        specify { expect(authorization).to be_sha256 }
        specify { expect(authorization.challenge).to eql(PkceHelpers::PKCE_CHALLENGE) }
        specify { expect(authorization.redirect_uri).to eql(redirect_uri) }
        specify { expect(authorization.scope).to eql('admin') }
        specify { expect(authorization.user).to eql(current_user) }
        specify { expect(authorization.expired_at).to be <= 10.minutes.from_now }
      end

      context "when the redirect_uri was omitted from the request" do
        before do
          get "/oauth/authorizations", params: params.except(:redirect_uri)
          post "/oauth/authorizations"
        end

        specify { expect(response.location).to start_with("#{redirect_uri}?") }
        specify { expect(authorization.redirect_uri).to be_nil }
      end

      context "when the user denies the request" do
        before do
          get "/oauth/authorizations", params: params
          post "/oauth/authorizations", params: { deny: '1' }
        end

        specify { expect(query['error']).to eql('access_denied') }
        specify { expect(query['state']).to eql(state) }
        specify { expect(query['iss']).to eql(Oauth::Issuer.identifier) }
        specify { expect(Authorization.count).to be_zero }
      end

      context "when the same request is approved twice" do
        before do
          get "/oauth/authorizations", params: params
          post "/oauth/authorizations"
          post "/oauth/authorizations"
        end

        specify { expect(response).to have_http_status(:bad_request) }
        specify { expect(Authorization.count).to be(1) }
      end

      context "when the client did not make an appropriate request" do
        before { post "/oauth/authorizations" }

        specify { expect(response).to have_http_status(:bad_request) }
      end

      context "when the state parameter looks malicious" do
        let(:state) { "<script>alert('hi');</script>" }

        before do
          get "/oauth/authorizations", params: params
          post "/oauth/authorizations"
        end

        # The state is opaque to the server and echoed back, properly encoded.
        specify { expect(query['state']).to eql(state) }
        specify { expect(response.location).not_to include('<script>') }
      end
    end
  end
end
