# frozen_string_literal: true

require 'rails_helper'

# RFC 9101 Section 6.2: a request object the client hosts.
RSpec.describe 'request objects by reference' do
  let(:signing_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwk) { JWT::JWK.new(signing_key.public_key, kid: 'key-1') }
  let(:url) { 'https://client.example.com/request/abc' }
  let(:client) { create(:client, jwks_uri: nil, jwks: { keys: [jwk.export] }, request_uris: [url]) }
  let(:user) { create(:user) }
  let(:claims) do
    {
      iss: client.to_param, aud: Oauth::Issuer.identifier, exp: 5.minutes.from_now.to_i,
      response_type: 'code', redirect_uri: client.redirect_uris[0], state: 's1', scope: 'admin',
      code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
    }
  end
  let(:request_object) { JWT.encode(claims, signing_key, 'RS256', kid: 'key-1', typ: 'oauth-authz-req+jwt') }
  let(:query) { Rack::Utils.parse_query(URI.parse(response.location).query) }
  let(:fetcher) { JwksFetcher.new }

  before do
    http_login(user)
    allow(JwksFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch_text)
  end

  it 'fetches and uses the registered request object' do
    allow(fetcher).to receive(:fetch_text).with(url).and_return(request_object)
    get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: url }
    expect(response).to have_http_status(:ok)
    post '/oauth/authorizations'
    expect(Rack::Utils.parse_query(URI.parse(response.location).query)['state']).to eql('s1')
  end

  it 'does not fetch a URL the client did not register (Section 10.4)' do
    expect(fetcher).not_to receive(:fetch_text)
    get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: 'https://elsewhere.example.com/x', redirect_uri: client.redirect_uris[0] }
    expect(query['error']).to eql('invalid_request_uri')
  end

  it 'reports a request object that cannot be fetched' do
    allow(fetcher).to receive(:fetch_text).and_raise(JwksFetcher::Error, 'unexpected response 404')
    get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: url, redirect_uri: client.redirect_uris[0] }
    expect(query['error']).to eql('invalid_request_uri')
  end

  it 'checks the signature of the fetched object' do
    forged = JWT.encode(claims, OpenSSL::PKey::RSA.generate(2048), 'RS256', kid: 'key-1', typ: 'oauth-authz-req+jwt')
    allow(fetcher).to receive(:fetch_text).and_return(forged)
    get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: url, redirect_uri: client.redirect_uris[0] }
    expect(query['error']).to eql('invalid_request_object')
  end

  it 'is not used by a client that requires pushed requests' do
    client.update!(require_pushed_authorization_requests: true)
    allow(fetcher).to receive(:fetch_text).and_return(request_object)
    get '/oauth/authorizations', params: { client_id: client.to_param, request_uri: url, redirect_uri: client.redirect_uris[0] }
    expect(query['error']).to eql('invalid_request')
  end

  it 'registers only https URLs' do
    expect(build(:client, request_uris: ['http://client.example.com/x'])).to be_invalid
    expect(build(:client, request_uris: ['https://client.example.com/x'])).to be_valid
  end

  it 'is advertised in the metadata' do
    get '/.well-known/oauth-authorization-server'
    expect(json[:request_uri_parameter_supported]).to be(true)
    expect(json[:require_request_uri_registration]).to be(true)
  end
end

RSpec.describe JwksFetcher, '#fetch_text' do
  it 'refuses plain http' do
    expect { described_class.new.fetch_text('http://client.example.com/x') }.to raise_error(described_class::Error)
  end

  it 'refuses a private address' do
    allow(Resolv).to receive(:getaddresses).and_return(['10.0.0.5'])
    expect { described_class.new.fetch_text('https://client.example.com/x') }.to raise_error(described_class::Error, /private/)
  end
end
