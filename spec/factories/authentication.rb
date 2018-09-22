FactoryBot.define do
  factory :authentication do
    user

    factory :password_authentication, class: PasswordAuthentication
  end
end
