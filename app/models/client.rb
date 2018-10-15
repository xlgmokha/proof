# frozen_string_literal: true

class Client < ApplicationRecord
  RESPONSE_TYPES = %w[code token].freeze
  audited
  has_secure_password
  has_many :authorizations

  validates :name, presence: true
  validates :redirect_uri, presence: true, format: { with: URI_REGEX }
  validates :uuid, presence: true, format: { with: UUID }

  after_initialize do
    self.uuid = SecureRandom.uuid unless uuid
    self.password = SecureRandom.base58(24) unless password_digest
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

  def valid_redirect_uri?(redirect_uri)
    self.redirect_uri == redirect_uri
  end

  def valid_response_type?(response_type)
    RESPONSE_TYPES.include?(response_type)
  end

  def redirect_url_for(user, oauth)
    sha256 = oauth[:code_challenge_method] == 'S256'
    authorization = authorizations.create!(
      user: user,
      challenge: oauth[:code_challenge],
      challenge_method: sha256 ? :sha256 : :plain
    )

    if oauth[:response_type] == 'code'
      redirect_url(code: authorization.code, state: oauth[:state])
    elsif oauth[:response_type] == 'token'
      access_token, = authorization.issue_tokens_to(
        self, token_types: [:access]
      )
      redirect_url(
        access_token: access_token.to_jwt,
        token_type: 'Bearer',
        expires_in: 5.minutes.to_i,
        scope: :admin,
        state: oauth[:state]
      )
    else
      redirect_url(error: 'unsupported_response_type', state: state)
    end
  end

  def redirect_url(fragments = {})
    URI.parse(
      "#{redirect_uri}#" + fragments.map do |(key, value)|
        "#{key}=#{value}" if value.present?
      end.compact.join("&")
    ).to_s
  end
end
