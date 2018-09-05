FactoryBot.define do
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
