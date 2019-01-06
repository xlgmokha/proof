# frozen_string_literal: true

module Scim
  class Controller < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
    before_action :apply_scim_content_type
    before_action :ensure_correct_content_type!
    before_action :authenticate!
    helper_method :current_user, :scim_type_for
    rescue_from StandardError do |error|
      Rails.logger.error(error)
      render "server_error", status: :server_error
    end
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
      @error = error
      @model = error.respond_to?(:model) ? error.model : error.record
      render "record_invalid", status: :bad_request
    end

    private

    def authenticate!
      Current.token = authenticate_with_http_token do |token|
        Token.authenticate(token)
      end
      options = { status: :unauthorized, formats: :scim }
      render "unauthorized", options unless Current.user?
    end

    def apply_scim_content_type
      response.headers['Content-Type'] = Mime[:scim].to_s
    end

    def ensure_correct_content_type!
      return if acceptable_content_type?

      status = :unsupported_media_type
      render 'unsupported_media_type', status: status, formats: :scim
    end

    def acceptable_content_type?
      [:scim, :json].include?(request&.content_mime_type&.symbol)
    end

    def scim_type_for(error)
      case error
      when ActiveRecord::RecordInvalid
        errors = error.record.errors.full_messages
        if errors.count == 1 &&
           errors[0].end_with?('has already been taken')
          return 'uniqueness'
        end
      end
      "invalidValue"
    end
  end
end
