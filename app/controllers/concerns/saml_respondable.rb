module SamlRespondable
  extend ActiveSupport::Concern

  def saml_params(allowed_params = [:SAMLRequest, :SAMLResponse, :SAMLEncoding, :SigAlg, :Signature, :RelayState])
    @saml_params ||=
      if request.post?
        params.permit(*allowed_params)
      else
        query_string = request.query_string
        on = query_string.include?("&amp;") ? "&amp;" : "&"
        result = Hash[query_string.split(on).map { |x| x.split("=", 2) }].symbolize_keys
        result.reject! { |key, value| !allowed_params.include?(key.to_sym) }
        result
      end
  end
end
