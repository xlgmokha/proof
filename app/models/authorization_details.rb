# frozen_string_literal: true

# RFC 9396: the `authorization_details` parameter, a JSON array of objects that
# each have a `type`. The types this server understands are listed in
# AUTHORIZATION_DETAILS_TYPES (comma separated); a client may use those it
# registered as `authorization_details_types`.
module AuthorizationDetails
  class Invalid < StandardError; end

  # Section 2.2: members every type may use, with the JSON type of each.
  STRINGS = %w[identifier].freeze
  STRING_ARRAYS = %w[locations actions datatypes privileges].freeze

  module_function

  def supported_types
    ENV.fetch('AUTHORIZATION_DETAILS_TYPES', '').split(',').map(&:strip).reject(&:empty?)
  end

  # The parsed and checked details, or nil when there are none. Raises
  # Invalid (`invalid_authorization_details`) when they cannot be used.
  def parse(value, client:)
    return if value.blank?

    details = value.is_a?(String) ? JSON.parse(value) : value
    details = details.map { |x| x.respond_to?(:to_unsafe_h) ? x.to_unsafe_h : x } if details.is_a?(Array)
    raise Invalid.new('authorization_details must be a non-empty JSON array.') unless details.is_a?(Array) && details.any?

    details.map { |x| check(x, client) }
  rescue JSON::ParserError
    raise Invalid.new('authorization_details is not valid JSON.')
  end

  def check(detail, client)
    raise Invalid.new('Each authorization detail must be an object.') unless detail.is_a?(Hash)

    detail = detail.stringify_keys
    type = detail['type']
    raise Invalid.new('Each authorization detail must have a type.') unless type.is_a?(String) && type.present?
    raise Invalid.new("The type #{type} is not supported.") unless supported_types.include?(type)
    raise Invalid.new("The client may not use the type #{type}.") unless client.authorization_details_types.include?(type)

    STRINGS.each { |k| raise Invalid.new("#{k} must be a string.") if detail.key?(k) && !detail[k].is_a?(String) }
    STRING_ARRAYS.each do |k|
      next unless detail.key?(k)
      raise Invalid.new("#{k} must be an array of strings.") unless detail[k].is_a?(Array) && detail[k].all?(String)
    end
    detail
  end

  # Section 7: what is asked for later may only be some of what was granted.
  def subset?(requested, granted)
    Array(requested).all? { |x| Array(granted).include?(x) }
  end
end
