# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, foreign_key: "user_id", class_name: UserSession.name

  validates :email, presence: true, email: true, uniqueness: {
    case_sensitive: false
  }

  after_initialize do
    self.uuid = SecureRandom.uuid unless uuid
  end

  def name_id_for(name_id_format)
    Saml::Kit::Namespaces::PERSISTENT == name_id_format ? uuid : email
  end

  def assertion_attributes_for(request)
    request.trusted? ? trusted_attributes_for(request) : {}
  end

  def issue_tokens_to(client)
    transaction do
      [
        Token.create!(subject: self, audience: client, token_type: :access),
        Token.create!(subject: self, audience: client, token_type: :refresh)
      ]
    end
  end

  def mfa
    Mfa.new(self)
  end

  def to_param
    uuid
  end

  class << self
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
    { id: uuid, email: email, created_at: created_at }
  end
end
