# frozen_string_literal: true

# Token endpoint grants that exchange a signed assertion for tokens.
module AssertionGrants
  extend ActiveSupport::Concern

  SAML_BEARER_GRANT = 'urn:ietf:params:oauth:grant-type:saml2-bearer'
  JWT_BEARER_GRANT = 'urn:ietf:params:oauth:grant-type:jwt-bearer'

  private

  def saml_assertion_grant(raw, scope)
    assertion = Saml::Kit::Assertion.new(
      Base64.urlsafe_decode64(raw)
    )
    return if assertion.invalid?

    user = if assertion.name_id_format == Saml::Kit::Namespaces::PERSISTENT
             User.find(assertion.name_id)
           else
             User.find_by!(email: assertion.name_id)
           end
    user.issue_tokens_to(current_client, scope: scope)
  end

  # RFC 7523 Section 2.1
  def jwt_bearer_grant(raw, scope)
    assertion = JwtBearerAssertion.new(
      current_client, audiences: assertion_audiences
    )
    claims = assertion.verify!(raw)
    User.from_assertion_subject(claims[:sub].to_s)&.issue_tokens_to(current_client, scope: scope)
  rescue JwtBearerAssertion::Invalid => error
    logger.error(error)
    nil
  end
end
