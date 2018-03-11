# frozen_string_literal: true

class Idp
  class << self
    def default(request)
      @default ||=
        begin
          host = "#{request.protocol}#{request.host}:#{request.port}"
          url_helpers = Rails.application.routes.url_helpers
          Saml::Kit::Metadata.build do |builder|
            builder.embed_signature = false
            builder.contact_email = 'hi@example.com'
            builder.organization_name = "Acme, Inc"
            builder.organization_url = url_helpers.root_url(host: host)
            builder.build_identity_provider do |x|
              x.add_single_sign_on_service(
                url_helpers.new_session_url(host: host), binding: :http_post
              )
              x.add_single_sign_on_service(
                url_helpers.new_session_url(host: host), binding: :http_redirect
              )
              x.add_single_logout_service(
                url_helpers.logout_url(host: host), binding: :http_post
              )
              x.name_id_formats = [
                Saml::Kit::Namespaces::EMAIL_ADDRESS,
                Saml::Kit::Namespaces::PERSISTENT,
                Saml::Kit::Namespaces::TRANSIENT,
              ]
              x.attributes << :id
              x.attributes << :email
              x.attributes << :created_at
            end
          end
        end
    end
  end
end
