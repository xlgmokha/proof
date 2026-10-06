# frozen_string_literal: true

module Oauth
  class ClientsController < ActionController::API
    include BearerAuthentication
    before_action :apply_cache_headers
    # The audience of the registration access token (RFC 7592).
    REGISTRATION_RESOURCE = -> { "#{Oauth::Issuer.identifier}/oauth/clients" }
    before_action :authenticate!, except: [:create]

    def show
      render status: :ok, formats: :json
    end

    # RFC 7591 Section 3
    def create
      error = metadata_type_error || assertion_grant_error
      return render json: { error: 'invalid_client_metadata', error_description: error }, status: :bad_request if error

      @client = Client.create!(transform(secure_params))
      # RFC 7592 Section 1: a long-lived credential for managing the client.
      @registration_access_token = @client.access_token(resource: REGISTRATION_RESOURCE.call, expired_at: 10.years.from_now).to_jwt
      render status: :created, formats: :json
    rescue ActiveRecord::RecordInvalid => error
      render_registration_error(error.record.errors)
    end

    # RFC 7592 Section 2.2: the request replaces the client's metadata.
    def update
      error = update_request_error || metadata_type_error || assertion_grant_error
      return render json: { error: 'invalid_client_metadata', error_description: error }, status: :bad_request if error

      attributes = transform(secure_params)
      # Section 2.2: a client that becomes confidential is given a secret, which
      # is in the response because it is not known anywhere else.
      @client.password = SecureRandom.base58(32) if @client.client_secret_none? && attributes[:token_endpoint_auth_method] != 'client_secret_none'
      @client.update!(attributes)
      render status: :ok, formats: :json
    rescue ActiveRecord::RecordInvalid => error
      render_registration_error(error.record.errors)
    end

    # RFC 7592 Section 2.3
    def destroy
      @client.destroy!
      head :no_content
    end

    private

    # RFC 7592 Section 2: the registration access token that was issued with
    # the client authorizes reading, updating and deleting that client.
    def authenticate!
      authenticate_bearer!
      return if performed?

      unless Client.where(id: params[:id]).exists?
        @access_token.revoke! if @access_token.resource == REGISTRATION_RESOURCE.call
        return challenge('invalid_token', 'The client does not exist.', status: :unauthorized)
      end
      unless @access_token.subject.to_param == params[:id] && @access_token.resource == REGISTRATION_RESOURCE.call
        return render json: { error: 'access_denied', error_description: 'The token is not for this client.' }, status: :forbidden
      end

      @client = @access_token.subject
      @registration_access_token = presented_bearer_tokens.first
    end

    ARRAY_METADATA = %w[redirect_uris grant_types response_types contacts authorization_details_types request_uris].freeze
    STRING_METADATA = %w[
      client_name token_endpoint_auth_method logo_uri client_uri tos_uri policy_uri jwks_uri scope software_id
      software_version tls_client_auth_subject_dn tls_client_auth_san_dns tls_client_auth_san_uri
      tls_client_auth_san_ip tls_client_auth_san_email
    ].freeze

    # RFC 7591 Section 3.2.2: members of the wrong type are refused, not dropped.
    def metadata_type_error
      ARRAY_METADATA.each do |key|
        next unless params.key?(key)

        value = params[key]
        return "#{key} must be an array of strings." unless value.is_a?(Array) && value.all?(String)
      end
      STRING_METADATA.each do |key|
        return "#{key} must be a string." if params.key?(key) && !params[key].is_a?(String)
      end
      return 'jwks must be an object.' if params.key?(:jwks) && !params[:jwks].respond_to?(:to_unsafe_h)

      nil
    end

    # RFC 7523 Section 3: an assertion names the user it is for, so only a
    # party the operator trusts may use these grants; open registration cannot.
    ASSERTION_GRANTS = [AssertionGrants::SAML_BEARER_GRANT, AssertionGrants::JWT_BEARER_GRANT].freeze

    def assertion_grant_error
      return unless (Array(params[:grant_types]) & ASSERTION_GRANTS).any?

      'The assertion grant types cannot be registered dynamically.'
    end

    # Fields the server owns (RFC 7592 Section 2.2) and the identity checks.
    READ_ONLY = %w[registration_access_token registration_client_uri client_secret_expires_at client_id_issued_at].freeze

    def update_request_error
      forbidden = READ_ONLY & params.keys
      return "#{forbidden.join(', ')} must not be included." if forbidden.any?
      return 'client_id must be included and match the client.' unless params[:client_id].to_s == @client.to_param
      return if params[:client_secret].blank? || @client.authenticate(params[:client_secret].to_s)

      'client_secret does not match the issued secret.'
    end

    def secure_params
      params.permit(
        :client_name, :token_endpoint_auth_method, :logo_uri, :client_uri, :tos_uri, :policy_uri,
        :jwks_uri, :scope, :software_id, :software_version,
        :require_pushed_authorization_requests, :require_signed_request_object,
        :tls_client_auth_subject_dn, :tls_client_auth_san_dns, :tls_client_auth_san_uri,
        :tls_client_auth_san_ip, :tls_client_auth_san_email, :tls_client_certificate_bound_access_tokens,
        jwks: {}, redirect_uris: [], grant_types: [], response_types: [], contacts: [], authorization_details_types: [], request_uris: []
      )
    end

    # RFC 7591 Section 2: grant_types defaults to authorization_code and
    # response_types follows from the grant types.
    def transform(params)
      grant_types = params[:grant_types].presence || %w[authorization_code]
      {
        name: params[:client_name],
        redirect_uris: params[:redirect_uris] || [],
        token_endpoint_auth_method: internal_auth_method(params.fetch(:token_endpoint_auth_method, 'client_secret_basic')),
        grant_types: grant_types,
        response_types: params[:response_types] || (grant_types.include?('authorization_code') ? %w[code] : []),
        scope: params[:scope],
        contacts: params[:contacts] || [],
        logo_uri: params[:logo_uri],
        client_uri: params[:client_uri],
        tos_uri: params[:tos_uri],
        policy_uri: params[:policy_uri],
        software_id: params[:software_id],
        software_version: params[:software_version],
        require_pushed_authorization_requests: params[:require_pushed_authorization_requests] || false,
        require_signed_request_object: params[:require_signed_request_object] || false,
        tls_client_auth_subject_dn: params[:tls_client_auth_subject_dn],
        tls_client_auth_san_dns: params[:tls_client_auth_san_dns],
        tls_client_auth_san_uri: params[:tls_client_auth_san_uri],
        tls_client_auth_san_ip: params[:tls_client_auth_san_ip],
        tls_client_auth_san_email: params[:tls_client_auth_san_email],
        tls_client_certificate_bound_access_tokens: params[:tls_client_certificate_bound_access_tokens] || false,
        authorization_details_types: params[:authorization_details_types] || [],
        request_uris: params[:request_uris] || [],
        jwks_uri: params[:jwks_uri],
        jwks: params[:jwks].presence&.to_h,
      }
    end

    # RFC 7591 Section 2 names the public client method `none`.
    def internal_auth_method(value)
      case value.to_s
      when 'none' then 'client_secret_none'
      when 'client_secret_none' then 'client_secret_none_is_not_a_registered_method'
      else value
      end
    end

    def render_registration_error(errors)
      json = {
        error: error_type_for(errors),
        error_description: errors.full_messages.join(' ')
      }
      render json: json, status: :bad_request
    end

    def apply_cache_headers
      response.headers["Cache-Control"] = "no-cache, no-store"
      response.headers["Pragma"] = "no-cache"
    end

    def error_type_for(errors)
      if errors[:redirect_uris].present?
        :invalid_redirect_uri
      else
        :invalid_client_metadata
      end
    end
  end
end
