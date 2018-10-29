# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'vcr'
require 'ffaker'
require 'factory_bot_rails'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.before :suite do
    FileUtils.rm_rf(Rails.root.join('doc/_cassettes/'))
    Net::Hippie.logger = Logger.new('/dev/null')
    VCR.configure do |x|
      x.cassette_library_dir = "doc/_cassettes"
      x.hook_into :webmock
    end
  end

  config.after :suite do
    template = IO.read('doc/_includes/curl.erb')
    erb = ERB.new(template)
    Dir["doc/_cassettes/**/*.yml"].each do |cassette|
      @configuration = YAML.safe_load(IO.read(cassette))
      result = erb.result(binding)
      IO.write("doc/_includes/#{File.basename(cassette).parameterize.gsub(/-yml/, '')}.html", result)
    end
  end
end

RSpec.describe "documentation" do
  let(:hippie) { Net::Hippie::Client.new(verify_mode: OpenSSL::SSL::VERIFY_NONE) }
  let(:host) { ENV.fetch('HOST', 'proof.test') }
  let(:scheme) { ENV.fetch('SCHEME', 'https') }
  let(:client) { create(:client) }
  let(:user) { create(:user) }

  specify do
    VCR.use_cassette("get-well-known-oauth-authorization-server") do
      response = hippie.get("#{scheme}://#{host}/.well-known/oauth-authorization-server")
      expect(response.code).to eql('200')
    end
  end

  specify do
    authorization = create(:authorization, client: client)
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'authorization_code', code: authorization.code }
    VCR.use_cassette("oauth-tokens-authorization-code") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'password', username: user.email, password: user.password }
    VCR.use_cassette("oauth-tokens-password") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'client_credentials' }
    VCR.use_cassette("oauth-tokens-client-credentials") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    saml_request = instance_double(Saml::Kit::AuthenticationRequest, id: Xml::Kit::Id.generate, issuer: Saml::Kit.configuration.entity_id, trusted?: true)
    saml = Saml::Kit::Assertion.build_xml(user, saml_request)
    body = { grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer', assertion: Base64.urlsafe_encode64(saml) }
    VCR.use_cassette("oauth-tokens-saml-assertion") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    refresh_token = create(:refresh_token, audience: client)
    body = { grant_type: 'refresh_token', refresh_token: refresh_token.to_jwt }
    VCR.use_cassette("oauth-tokens-refresh-token") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    body = {
      redirect_uris: [generate(:uri), generate(:uri)],
      client_name: FFaker::Name.name,
      token_endpoint_auth_method: :client_secret_basic,
      logo_uri: generate(:uri),
      jwks_uri: generate(:uri),
    }
    VCR.use_cassette("oauth-dynamic-client-registration") do
      response = hippie.post("#{scheme}://#{host}/oauth/clients", body: body)
      expect(response.code).to eql('201')
    end
  end

  specify do
    code_verifier = SecureRandom.hex(128)
    authorization = create(:authorization, client: client, challenge: Base64.urlsafe_encode64(Digest::SHA256.hexdigest(code_verifier)), challenge_method: :sha256)
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'authorization_code', code: authorization.code, code_verifier: code_verifier }
    VCR.use_cassette("oauth-tokens-pkce") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    token = create(:access_token)
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { token: token.to_jwt }
    VCR.use_cassette("oauth-token-introspection") do
      response = hippie.post("#{scheme}://#{host}/oauth/tokens/introspect", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-service-provider-config") do
      response = hippie.get("#{scheme}://#{host}/scim/v2/ServiceProviderConfig")
      expect(response.code).to eql('200')
    end
  end
end
