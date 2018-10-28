# frozen_string_literal: true
require File.expand_path('../../config/environment', __FILE__)
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
  let(:client) { Net::Hippie::Client.new(verify_mode: OpenSSL::SSL::VERIFY_NONE) }
  let(:host) { ENV.fetch('HOST', 'proof.test') }
  let(:scheme) { ENV.fetch('SCHEME', 'https') }

  specify do
    VCR.use_cassette("get-well-known-oauth-authorization-server") do
      response = client.get("#{scheme}://#{host}/.well-known/oauth-authorization-server")
      expect(response.code).to eql('200')
    end
  end
end
