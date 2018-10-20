# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { FFaker::Internet.email }
    password { FFaker::Internet.password }

    trait :mfa_configured do
      mfa_secret { ::ROTP::Base32.random_base32 }
    end
  end
end
