# frozen_string_literal: true

class Client < ApplicationRecord
  has_secure_token :secret
  has_many :authorizations

  after_initialize do
    self.uuid = SecureRandom.uuid unless uuid
    self.secret = self.class.generate_unique_secure_token unless secret
  end

  def to_param
    uuid
  end

  def redirect_uri_path(code:)
    redirect_uri + '?code=' + code
  end
end
