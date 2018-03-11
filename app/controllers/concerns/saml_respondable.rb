# frozen_string_literal: true

module SamlRespondable
  extend ActiveSupport::Concern
  ALLOWED_SAML_PARAMS = [
    :RelayState,
    :SAMLEncoding,
    :SAMLRequest,
    :SAMLResponse,
    :SigAlg,
    :Signature,
  ].freeze

  def binding_for(binding, location)
    if binding == :http_post
      Saml::Kit::Bindings::HttpPost.new(location: location)
    else
      Saml::Kit::Bindings::HttpRedirect.new(location: location)
    end
  end

  def saml_params(allowed_params = ALLOWED_SAML_PARAMS)
    @saml_params ||=
      if request.post?
        params.permit(*allowed_params)
      else
        query_string = request.query_string
        on = query_string.include?("&amp;") ? "&amp;" : "&"
        result = Hash[query_string.split(on).map { |x| x.split("=", 2) }]
        result = result.symbolize_keys
        result.select! { |key, _value| allowed_params.include?(key.to_sym) }
        result
      end
  end
end
