FactoryBot.define do
  factory :user_session do
    user
    ip { FFaker::Internet.ip_v4_address }
    user_agent  { "Googlebot/2.1 (+http://www.google.com/bot.html)" }
    accessed_at { 1.minute.ago }

    trait :idle_timeout_expired do
      accessed_at { 31.minutes.ago }
    end

    trait :absolute_timeout_expired do
      created_at { (24.hours + 1.second).ago }
    end

    trait :revoked do
      revoked_at { 1.minute.ago }
    end

    trait :sudo do
      sudo_enabled_at { 1.minute.ago }
    end
  end
end
