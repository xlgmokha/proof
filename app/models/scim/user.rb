# frozen_string_literal: true

module SCIM
  class User
    include ActiveModel::Model
    attr_accessor :id, :schemas, :userName, :name, :locale, :timezone, :password

    validate :must_be_user_schema
    validates :id, format: { with: ApplicationRecord::UUID }, allow_blank: true
    validates :locale, presence: true, inclusion: ::User::VALID_LOCALES
    validates :timezone, presence: true, inclusion: ::User::VALID_TIMEZONES
    validates :userName, presence: true, email: true

    def save!
      validate!
      if id.present?
        user = ::User.find(id)
        ensure_password_update_is_allowed!(user) if password.present?
        user.update!(to_h)
      else
        user = ::User.create!(to_h(password: password || SecureRandom.hex(32)))
      end
      user
    end

    private

    def must_be_user_schema
      errors.add(:schemas, :invalid) unless user_schema?
    end

    def user_schema?
      schemas == [Scim::Kit::V2::Schemas::USER]
    end

    def ensure_password_update_is_allowed!(user)
      error = I18n.t('scim.errors.user.password_update_not_permitted')
      raise StandardError.new(error) unless Current.user == user
    end

    def to_h(extra = {})
      x = { email: userName, locale: locale, timezone: timezone }
      x[:password] = password if password.present?
      x.merge(extra)
    end
  end
end
