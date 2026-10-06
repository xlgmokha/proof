# frozen_string_literal: true

class User < ApplicationRecord
  VALID_TIMEZONES = ActiveSupport::TimeZone::MAPPING.values
  VALID_LOCALES = I18n.available_locales.map(&:to_s)
  audited except: [:password_digest, :mfa_secret]
  has_secure_password
  has_many :sessions,
    class_name: 'UserSession',
    inverse_of: :user,
    dependent: :delete_all

  validates :email, presence: true, email: true, uniqueness: {
    case_sensitive: false
  }
  validates :timezone, inclusion: VALID_TIMEZONES
  validates :locale, inclusion: VALID_LOCALES

  scope :scim_search, ->(filter) { Scim::Search.new(User).for(filter) }

  def name_id_for(name_id_format)
    Saml::Kit::Namespaces::PERSISTENT == name_id_format ? id : email
  end

  def assertion_attributes_for(request)
    request.trusted? ? trusted_attributes_for(request) : {}
  end

  def issue_tokens_to(client, token_types: [:access, :refresh])
    transaction do
      token_types.map do |x|
        Token.create!(subject: self, audience: client, token_type: x)
      end
    end
  end

  def mfa
    Mfa.new(self)
  end

  class << self
    def scim_mapper
      Scim::User::ATTRIBUTES
    end

    # Resolves the `sub` of a JWT assertion, which is either a user id or an email.
    def from_assertion_subject(subject)
      return if subject.blank?

      subject.match?(ApplicationRecord::UUID) ? find_by(id: subject) : find_by(email: subject)
    end

    def login(email, password)
      return if email.blank? || password.blank?

      user = User.find_by!(email: email)
      user.authenticate(password) ? user : nil
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  private

  def trusted_attributes_for(_request)
    { id: id, email: email, created_at: created_at }
  end
end
