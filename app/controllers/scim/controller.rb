# frozen_string_literal: true

module Scim
  class Controller < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include BearerAuthentication
    before_action :apply_scim_content_type
    before_action :ensure_correct_content_type!
    before_action :authenticate!
    helper_method :current_user
    rescue_from StandardError do |error|
      Rails.logger.error(error)
      render "scim/server_error", status: :internal_server_error
    end
    rescue_from Scim::Error, with: :render_scim_error
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActiveModel::ValidationError, with: :record_invalid
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    def current_user
      Current.user
    end

    def current_user?
      Current.user?
    end

    protected

    def not_found
      render json: {
        schemas: [Scim::Kit::V2::Messages::ERROR],
        detail: "Resource #{params[:id]} not found",
        status: "404",
      }.to_json, status: :not_found
    end

    def record_invalid(error)
      render_scim_error(Scim::Error.from(error))
    end

    def render_scim_error(error)
      render json: error.to_h.to_json, status: error.status
    end

    private

    def authenticate!
      Current.token = authenticate_with_http_token do |token|
        Token.authenticate(token, resource: '/scim/v2', subject_type: 'User')
      end
      return if Current.user?

      # RFC 6750 Section 3: say how to authenticate, and why a credential was refused.
      presented = request.authorization.present?
      response.headers['WWW-Authenticate'] = challenge_for(
        'Bearer', presented ? 'invalid_token' : nil, presented ? 'The access token is invalid.' : nil, nil
      )
      render "scim/unauthorized", status: :unauthorized, formats: :scim
    end

    def apply_scim_content_type
      response.headers['Content-Type'] = Mime[:scim].to_s
    end

    def ensure_correct_content_type!
      return if acceptable_content_type?

      status = :unsupported_media_type
      render "scim/unsupported_media_type", status: status, formats: :scim
    end

    # Requests without a body (GET, DELETE) have no content type to check.
    def acceptable_content_type?
      return true if request.content_mime_type.nil? && request.raw_post.blank?

      [:scim, :json].include?(request.content_mime_type&.symbol)
    end
  end
end
