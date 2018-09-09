FactoryBot.define do
  factory :token do
    uuid { SecureRandom.uuid }
    authorization { nil }
    association :audience, factory: :client
    association :subject, factory: :user

    factory :access_token do
      token_type { :access }
    end

    factory :refresh_token do
      token_type { :refresh }
    end
  end

  factory :authorization do
    user
    client
  end

  factory :client do
    uuid { SecureRandom.uuid }
    name { FFaker::Name.name }
    redirect_uri { FFaker::Internet.uri('https') }
  end

  factory :user do
    email { FFaker::Internet.email }
    uuid { SecureRandom.uuid }
    password { FFaker::Internet.password }

    trait :mfa_configured do
      mfa_secret { ::ROTP::Base32.random_base32 }
    end
  end
end
