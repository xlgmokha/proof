# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'vcr'
require 'ffaker'
require 'factory_bot_rails'

$server = Capybara::Server.new(Rack::Builder.new do
  map "/" do
    run Rails.application
  end
end.to_app)

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include(Module.new do
    def server
      $server
    end
  end)

  config.before :suite do
    puts "Booting"
    $server.boot
    print "." until $server.responsive?
    FileUtils.rm_rf(Rails.root.join('tmp/_cassettes/'))
    Net::Hippie.logger = Logger.new('/dev/null')
    VCR.configure do |x|
      x.cassette_library_dir = "tmp/_cassettes"
      x.hook_into :webmock
    end
  end

  config.after :suite do
    erb = ERB.new(IO.read('doc/_includes/curl.erb'))
    Dir["tmp/_cassettes/**/*.yml"].each do |cassette|
      @configuration = YAML.safe_load(IO.read(cassette))
      result = erb.result(binding)
      IO.write("doc/_includes/#{File.basename(cassette).parameterize.gsub(/-yml/, '')}.html", result)
    end
  end
end

class UserAgent
  def login_with(scheme: 'https', host:, port:, email:, password:, issuer:)
    authn_request = Saml::Kit::AuthenticationRequest.build(configuration: Saml::Kit.configuration) do |x|
      x.issuer = issuer
      x.embed_signature = false
    end
    body = { SAMLRequest: Base64.strict_encode64(authn_request.to_xml) }
    response = client.post("#{scheme}://#{host}:#{port}/session/new", body: URI.encode_www_form(body))
    form = Nokogiri::HTML(response.body).css('form').last
    authenticity_token = form&.css('[name=authenticity_token]')&.first&.attribute('value')&.value
    body.merge!(
      'authenticity_token' => authenticity_token,
      'user[email]' => email,
      'user[password]' => password
    )
    session_cookie = parse_cookie(response['Set-Cookie'])
    response = client.post("#{scheme}://#{host}:#{port}/session", headers: { 'Cookie' => session_cookie }, body: URI.encode_www_form(body))

    session_cookie = parse_cookie(response['Set-Cookie'])
    response = client.get(response['Location'], headers: { 'Cookie' => session_cookie })
    encoded_saml_response = Nokogiri::HTML(response.body).css('#SAMLResponse').attribute('value').value
    Saml::Kit::Bindings::HttpPost.new(location: '').deserialize(SAMLResponse: encoded_saml_response)
  end

  private

  def client
    @client ||= Net::Hippie::Client.new(verify_mode: OpenSSL::SSL::VERIFY_NONE, headers: {})
  end

  def parse_cookie(value)
    value.split(';')[0]
  end
end

RSpec.describe "documentation" do
  let(:hippie) { Net::Hippie::Client.new(verify_mode: OpenSSL::SSL::VERIFY_NONE) }
  let(:client) { create(:client) }
  let(:user) { create(:user) }
  let(:user_agent) { UserAgent.new }
  let(:scheme) { 'http' }
  let(:host) { server.host }
  let(:port) { server.port }
  let(:url_prefix) { "#{scheme}://#{host}:#{port}" }

  specify do
    VCR.use_cassette("get-well-known-oauth-authorization-server") do
      response = hippie.get("#{url_prefix}/.well-known/oauth-authorization-server")
      expect(response.code).to eql('200')
    end
  end

  specify do
    authorization = create(:authorization, client: client)
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'authorization_code', code: authorization.code }
    VCR.use_cassette("oauth-tokens-authorization-code") do
      response = hippie.post("#{url_prefix}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'password', username: user.email, password: user.password }
    VCR.use_cassette("oauth-tokens-password") do
      response = hippie.post("#{url_prefix}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'client_credentials' }
    VCR.use_cassette("oauth-tokens-client-credentials") do
      response = hippie.post("#{url_prefix}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  xspecify do
    VCR.use_cassette("oauth-tokens-saml-assertion") do
      saml = user_agent.login_with(scheme: scheme, host: host, port: port, email: user.email, password: user.password, issuer: 'https://saml-kit-airport.herokuapp.com/service_providers/73db6338-5d35-4271-812c-d4c6fbe45cca')
      headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
      body = { grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer', assertion: Base64.urlsafe_encode64(saml.assertion.to_xml) }
      response = hippie.post("#{url_prefix}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    refresh_token = create(:refresh_token, audience: client)
    body = { grant_type: 'refresh_token', refresh_token: refresh_token.to_jwt }
    VCR.use_cassette("oauth-tokens-refresh-token") do
      response = hippie.post("#{url_prefix}/oauth/tokens", body: body, headers: headers)
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
      response = hippie.post("#{url_prefix}/oauth/clients", body: body)
      expect(response.code).to eql('201')
    end
  end

  specify do
    code_verifier = SecureRandom.hex(128)
    authorization = create(:authorization, client: client, challenge: Base64.urlsafe_encode64(Digest::SHA256.hexdigest(code_verifier)), challenge_method: :sha256)
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { grant_type: 'authorization_code', code: authorization.code, code_verifier: code_verifier }
    VCR.use_cassette("oauth-tokens-pkce") do
      response = hippie.post("#{url_prefix}/oauth/tokens", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    token = create(:access_token)
    headers = { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
    body = { token: token.to_jwt }
    VCR.use_cassette("oauth-token-introspection") do
      response = hippie.post("#{url_prefix}/oauth/tokens/introspect", body: body, headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-service-provider-config") do
      response = hippie.get("#{url_prefix}/scim/v2/ServiceProviderConfig")
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-schemas") do
      headers = { 'Content-Type' => Mime[:scim].to_s }
      response = hippie.get("#{url_prefix}/scim/v2/Schemas", headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-schemas-users") do
      headers = { 'Content-Type' => Mime[:scim].to_s }
      response = hippie.get("#{url_prefix}/scim/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:User", headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-schemas-groups") do
      headers = { 'Content-Type' => Mime[:scim].to_s }
      response = hippie.get("#{url_prefix}/scim/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:Group", headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-resource-types") do
      headers = { 'Content-Type' => Mime[:scim].to_s }
      response = hippie.get("#{url_prefix}/scim/v2/ResourceTypes", headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-resource-type-user") do
      headers = { 'Content-Type' => Mime[:scim].to_s }
      response = hippie.get("#{url_prefix}/scim/v2/ResourceTypes/User", headers: headers)
      expect(response.code).to eql('200')
    end
  end

  specify do
    VCR.use_cassette("scim-resource-type-group") do
      headers = { 'Content-Type' => Mime[:scim].to_s }
      response = hippie.get("#{url_prefix}/scim/v2/ResourceTypes/Group", headers: headers)
      expect(response.code).to eql('200')
    end
  end
end
