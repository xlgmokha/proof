FactoryBot.define do
  factory :user do
    email { FFaker::Internet.email }
    uuid { SecureRandom.uuid }
    password { FFaker::Internet.password }

    trait :mfa_configured do
      tfa_secret { ::ROTP::Base32.random_base32 }
    end
  end
end
