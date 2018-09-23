# frozen_string_literal: true

module SCIM
  class User
    include ActiveModel::Model
    attr_accessor :id, :schemas, :userName, :name, :locale, :timezone, :password

    validate :must_be_user_schema
    validates :id, format: { with: /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ }, if: proc { |x| x.id.present? }
    validates :locale, presence: true, inclusion: I18n.available_locales.map(&:to_s)
    validates :timezone, presence: true, inclusion: ::User::VALID_TIMEZONES
    validates :userName, presence: true, email: true

    def save!
      validate!
      if id.present?
        user = ::User.find_by!(uuid: id)
        ensure_password_update_is_allowed!(user) if password.present?
        user.update!(to_h)
      else
        user = ::User.create!(to_h(password: password || SecureRandom.hex(32)))
      end
      user
    end

    private

    def must_be_user_schema
      errors.add(:schemas, "is invalid") unless schemas == [SCIM::Schema::USER]
    end

    def ensure_password_update_is_allowed!(user)
      raise StandardError.new(I18n.t('.password_update_not_permitted')) unless Current.user == user
    end

    def to_h(extra = {})
      x = { email: userName, locale: locale, timezone: timezone }
      x[:password] = password if password.present?
      x.merge(extra)
    end
  end
end
