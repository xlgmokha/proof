# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    name { FFaker::Name.name }
    redirect_uris { [FFaker::Internet.uri('https')] }
    logo_uri { FFaker::Internet.uri('https') }
    jwks_uri { FFaker::Internet.uri('https') }

    trait :public do
      token_endpoint_auth_method { :client_secret_none }
      grant_types { %w[authorization_code refresh_token] }
    end
  end
end
