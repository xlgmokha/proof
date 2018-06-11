FactoryBot.define do
  factory :user do
    email { FFaker::Internet.email }
    uuid { SecureRandom.uuid }
    password { FFaker::Internet.password }
  end
end
