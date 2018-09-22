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

    trait :revoked do
      revoked_at { Time.now }
    end

    trait :expired do
      expired_at { 1.minute.ago }
    end
  end
end
