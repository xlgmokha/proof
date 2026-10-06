# frozen_string_literal: true

# RFC 6749 Section 3.3: scopes are a space-delimited list of case-sensitive
# strings.
module Scopes
  SUPPORTED = %w[admin].freeze
  # Granted when a request does not ask for a specific scope.
  DEFAULT = SUPPORTED

  # Characters allowed by RFC 6749 Section 3.3: %x21 / %x23-5B / %x5D-7E.
  TOKEN = /\A[\x21\x23-\x5B\x5D-\x7E]+\z/

  module_function

  def parse(value)
    value.to_s.split(' ')
  end

  def format(scopes)
    Array(scopes).join(' ')
  end

  def valid?(scopes)
    scopes.all? { |x| TOKEN.match?(x) && SUPPORTED.include?(x) }
  end

  # Scope that may be granted for a request, or nil when it asks for scopes this
  # server does not support or the client is not allowed to use.
  def resolve(value, allowed: SUPPORTED)
    requested = value.present? ? parse(value).uniq : DEFAULT & allowed
    requested if valid?(requested) && subset?(requested, allowed)
  end

  def subset?(requested, granted)
    (requested - granted).empty?
  end
end
