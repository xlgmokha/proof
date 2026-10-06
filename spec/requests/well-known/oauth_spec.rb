# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/.well-known/oauth-authorization-server" do
  describe "GET /.well-known/oauth-authorization-server" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get "/.well-known/oauth-authorization-server" }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.content_type).to start_with("application/json") }
    specify { expect(response.headers['Set-Cookie']).to be_nil }
    specify { expect(json[:issuer]).to eql(root_url) }
    specify { expect(json[:authorization_endpoint]).to eql(oauth_authorizations_url) }
    specify { expect(json[:token_endpoint]).to eql(oauth_tokens_url) }
    specify { expect(json[:token_endpoint_auth_methods_supported]).to match_array(%w[client_secret_basic client_secret_post]) }
    specify { expect(json[:token_endpoint_auth_signing_alg_values_supported]).to match_array(['RS256']) }
    specify { expect(json[:userinfo_endpoint]).to eql(oauth_me_url) }
    specify { expect(json[:jwks_uri]).to eql(jwks_url) }
    specify { expect(json[:revocation_endpoint]).to eql(revoke_oauth_tokens_url) }
    specify { expect(json[:introspection_endpoint]).to eql(introspect_oauth_tokens_url) }
    specify { expect(json[:grant_types_supported]).to match_array(Client::GRANT_TYPES) }
    specify { expect(json[:code_challenge_methods_supported]).to match_array(%w[plain S256]) }
    specify { expect(json[:registration_endpoint]).to eql(oauth_clients_url) }
    specify { expect(json[:scopes_supported]).to be_empty }
    specify { expect(json[:response_types_supported]).to match_array(Client::RESPONSE_TYPES) }
    specify { expect(json[:service_documentation]).to eql(root_url + 'doc') }
    specify { expect(json[:ui_locales_supported]).to eql(I18n.available_locales.map(&:to_s)) }
  end

  describe "GET /.well-known/jwks.json" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get "/.well-known/jwks.json" }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.content_type).to start_with("application/json") }
    specify { expect(json[:keys].size).to be(1) }
    specify { expect(json[:keys][0]).to include(kty: 'RSA', use: 'sig', alg: 'RS256') }
    specify { expect(json[:keys][0]).not_to include(:d, :p, :q) }

    it 'publishes the key that verifies issued tokens' do
      jwt = create(:access_token).to_jwt
      key = JWT::JWK.import(json[:keys][0]).verify_key
      expect { JWT.decode(jwt, key, true, algorithm: 'RS256') }.not_to raise_error
      expect(JWT.decode(jwt, nil, false)[1]['kid']).to eql(json[:keys][0][:kid])
    end
  end
end
