module SamlRespondable
  extend ActiveSupport::Concern

  def saml_params
    params.permit(:SAMLRequest, :SAMLResponse, :SAMLEncoding, :SigAlg, :Signature, :RelayState)
  end

  def raw_params
    if request.post?
      saml_params
    else
      Hash[request.query_string.split("&amp;").map { |x| x.split("=", 2) }].symbolize_keys
    end
  end
end
