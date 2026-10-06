# frozen_string_literal: true

require 'rails_helper'

# RFC 9728: OAuth 2.0 Protected Resource Metadata
RSpec.describe '/.well-known/oauth-protected-resource' do
  describe 'GET /.well-known/oauth-protected-resource' do
    before { get '/.well-known/oauth-protected-resource' }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.content_type).to start_with('application/json') }
    specify { expect(response.headers['Set-Cookie']).to be_nil }
    # Section 3.3: the resource is the URL the metadata was derived from.
    specify { expect(json[:resource]).to eql('http://www.example.com') }
    specify { expect(json[:authorization_servers]).to eql([Oauth::Issuer.identifier]) }
    specify { expect(json[:bearer_methods_supported]).to match_array(%w[header body]) }
    specify { expect(json[:scopes_supported]).to match_array(Scopes::SUPPORTED) }
    specify { expect(json[:dpop_signing_alg_values_supported]).to include('ES256') }
    specify { expect(json[:jwks_uri]).to eql(jwks_url) }
  end

  describe 'GET /.well-known/oauth-protected-resource/oauth/me' do
    before { get '/.well-known/oauth-protected-resource/oauth/me' }

    # Section 3.1: the well-known URI is inserted between host and path.
    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:resource]).to eql('http://www.example.com/oauth/me') }
  end

  describe 'GET for an unknown resource' do
    before { get '/.well-known/oauth-protected-resource/nope' }

    specify { expect(response).to have_http_status(:not_found) }
  end

  describe 'the challenge of a protected resource' do
    before { get '/oauth/me' }

    # Section 5.1
    specify { expect(response.headers['WWW-Authenticate']).to include('resource_metadata="http://www.example.com/.well-known/oauth-protected-resource"') }
  end
end
