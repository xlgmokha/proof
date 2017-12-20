module SamlRespondable
  extend ActiveSupport::Concern

  def saml_params(allowed_params = [:SAMLRequest, :SAMLResponse, :SAMLEncoding, :SigAlg, :Signature, :RelayState])
    if request.post?
      params.permit(*allowed_params)
    else
      result = Hash[request.query_string.split("&amp;").map { |x| x.split("=", 2) }].symbolize_keys
      result.reject! { |key, value| !allowed_params.include?(key.to_sym) }
      result
    end
  end
end
