# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    # Unique in both the prefix and suffix so partial-match searches are deterministic.
    sequence(:email) { |n| "u#{SecureRandom.hex(3)}n#{n}@example-#{SecureRandom.hex(4)}.com" }
    password { FFaker::Internet.password }

    trait :mfa_configured do
      mfa_secret { ::ROTP::Base32.random_base32 }
    end
  end
end
