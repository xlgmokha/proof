# frozen_string_literal: true

# How the user authenticated (RFC 9470, RFC 9068 Section 2.2.1): the
# authentication context class reference (`acr`) and when it happened
# (`auth_time`). This application knows two classes: a password login, and a
# password login followed by a one time code.
class AuthenticationContext
  PASSWORD = 'urn:proof:acr:password'
  MFA = 'urn:proof:acr:mfa'
  # Section 3: a stronger class satisfies a requirement for a weaker one.
  SATISFIES = { MFA => [MFA, PASSWORD], PASSWORD => [PASSWORD] }.freeze
  SUPPORTED = [PASSWORD, MFA].freeze

  attr_reader :acr, :auth_time

  # The context of the signed in user, from the login and the MFA step.
  def self.for(user_session, mfa_session, user)
    mfa_session = mfa_session.to_h.with_indifferent_access
    if user.mfa.setup? && mfa_session[:issued_at].present?
      new(MFA, mfa_session[:issued_at].to_i)
    else
      new(PASSWORD, user_session.created_at.to_i)
    end
  end

  def initialize(acr, auth_time)
    @acr = acr
    @auth_time = auth_time
  end

  # Whether this context meets one of the (space separated) classes asked for.
  def satisfies?(acr_values)
    wanted = acr_values.to_s.split(' ')
    wanted.empty? || wanted.any? { |x| SATISFIES.fetch(acr, []).include?(x) }
  end

  # Whether the authentication is older than `max_age` seconds.
  def older_than?(max_age)
    max_age.present? && Time.current.to_i - auth_time > max_age.to_i
  end

  def to_h
    { acr: acr, auth_time: auth_time }
  end
end
