FactoryBot.define do
  sequence(:email) { |n| FFaker::Internet.email }
  sequence(:password) { |n| FFaker::Internet.password }
end
