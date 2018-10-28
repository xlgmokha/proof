# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/.well-known/oauth-authorization-server" do
  describe "GET /.well-known/oauth-authorization-server" do
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before { get "/.well-known/oauth-authorization-server" }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.content_type).to eql("application/json") }
    specify { expect(json[:issuer]).to eql(root_url) }
    specify { expect(json[:authorization_endpoint]).to eql(oauth_authorizations_url) }
    specify { expect(json[:token_endpoint]).to eql(oauth_tokens_url) }
    specify { expect(json[:token_endpoint_auth_methods_supported]).to match_array(['client_secret_basic']) }
    specify { expect(json[:token_endpoint_auth_signing_alg_values_supported]).to match_array(['RS256']) }
    specify { expect(json[:userinfo_endpoint]).to eql(oauth_me_url) }
    specify { expect(json[:jwks_uri]).to eql('') }
    specify { expect(json[:registration_endpoint]).to eql(oauth_clients_url) }
    specify { expect(json[:scopes_supported]).to match_array([]) }
    specify { expect(json[:response_types_supported]).to match_array(Client::RESPONSE_TYPES) }
    specify { expect(json[:service_documentation]).to eql(root_url + 'doc') }
    specify { expect(json[:ui_locales_supported]).to eql(I18n.available_locales.map(&:to_s)) }
  end
end
