# frozen_string_literal: true

# RFC 8707 Section 2: a resource indicator is an absolute URI without a
# fragment component.
module ResourceIndicator
  module_function

  # Section 2: the server decides which resources a client may name. Its own
  # resources are open to every client; others are granted per client.
  def permitted?(client, value)
    Oauth::Issuer.resource?(value) || client.resources.include?(value)
  end

  def valid?(value)
    uri = URI.parse(value.to_s)
    uri.absolute? && uri.fragment.nil? && uri.host.present? && value.to_s.exclude?('#')
  rescue URI::InvalidURIError
    false
  end
end
