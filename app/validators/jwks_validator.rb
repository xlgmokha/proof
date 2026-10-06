# frozen_string_literal: true

# Validates a JSON Web Key Set (RFC 7517 Section 5) that only carries public keys.
class JwksValidator < ActiveModel::EachValidator
  PRIVATE_MEMBERS = %w[d p q dp dq qi k oth].freeze

  def validate_each(record, attribute, value)
    return if value.blank?

    keys = value.is_a?(Hash) ? value['keys'] : nil
    if !key_set?(keys)
      record.errors.add(attribute, 'must be a JSON Web Key Set')
    elsif keys.any? { |x| (x.keys & PRIVATE_MEMBERS).any? }
      record.errors.add(attribute, 'must not contain private keys')
    end
  end

  private

  def key_set?(keys)
    keys.is_a?(Array) && keys.all? { |x| x.is_a?(Hash) && x['kty'].present? }
  end
end
