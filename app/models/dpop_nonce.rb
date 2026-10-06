# frozen_string_literal: true

# RFC 9449 Section 8: server-provided nonces. They are derived from the time
# and a secret, so nothing is stored; the current and the previous period are
# accepted, which gives a nonce between 5 and 10 minutes to be used.
module DpopNonce
  PERIOD = 5.minutes.to_i

  module_function

  # Whether this server asks for nonces (DPOP_NONCE_REQUIRED=true).
  def required?
    ENV['DPOP_NONCE_REQUIRED'] == 'true'
  end

  def current
    for_period(Time.current.to_i / PERIOD)
  end

  def valid?(value)
    return false unless value.is_a?(String)

    period = Time.current.to_i / PERIOD
    [period, period - 1].any? { |x| ActiveSupport::SecurityUtils.secure_compare(for_period(x), value) }
  end

  def for_period(period)
    digest = OpenSSL::HMAC.digest('SHA256', Rails.application.secret_key_base.to_s, "dpop-nonce:#{period}")
    Base64.urlsafe_encode64(digest, padding: false)
  end
end
