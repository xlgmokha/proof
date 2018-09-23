# frozen_string_literal: true

class Client < ApplicationRecord
  audited
  has_secure_token :secret
  has_many :authorizations

  after_initialize do
    self.uuid = SecureRandom.uuid unless uuid
    self.secret = self.class.generate_unique_secure_token unless secret
  end

  def authenticate(provided_secret)
    return self if secret == provided_secret
  end

  def access_token
    transaction do
      Token
        .active.where(subject: self, audience: self)
        .update_all(revoked_at: Time.now)
      Token.create!(subject: self, audience: self, token_type: :access)
    end
  end

  def to_param
    uuid
  end

  def redirect_uri_path(code:, state: nil)
    result = redirect_uri + '?code=' + code
    result += "&state=#{state}" if state.present?
    result
  end
end
