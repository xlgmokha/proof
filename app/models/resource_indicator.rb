# frozen_string_literal: true

# RFC 8707 Section 2: a resource indicator is an absolute URI without a
# fragment component.
module ResourceIndicator
  module_function

  def valid?(value)
    uri = URI.parse(value.to_s)
    uri.absolute? && uri.fragment.nil? && uri.host.present? && value.to_s.exclude?('#')
  rescue URI::InvalidURIError
    false
  end
end
