# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  validates :email, presence: true, email: true, uniqueness: true

  after_initialize do
    self.uuid = SecureRandom.uuid unless uuid
  end

  def name_id_for(name_id_format)
    Saml::Kit::Namespaces::PERSISTENT == name_id_format ? uuid : email
  end

  def assertion_attributes_for(request)
    request.trusted? ? trusted_attributes_for(request) : {}
  end

  def tfa
    Tfa.new(self)
  end

  def access_token(audience)
    BearerToken.new.encode(sub: uuid, aud: audience)
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

    def authenticate_token(token)
      token = BearerToken.new.decode(token)
      return if token.empty?
      User.find_by(uuid: token[:sub])
    end
  end

  private

  def trusted_attributes_for(_request)
    {
      id: uuid,
      email: email,
      created_at: created_at,
    }
  end
end
