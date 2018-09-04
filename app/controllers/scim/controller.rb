# frozen_string_literal: true

module Scim
  class Controller < ActionController::Base
    protect_from_forgery with: :null_session
    before_action :apply_scim_content_type
    before_action :ensure_correct_content_type!
    before_action :authenticate!
    helper_method :current_user
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid do |error|
      @error = error
      @model = error.record
      render "record_invalid", status: :bad_request
    end

    def current_user
      @current_user ||= authenticate_with_http_token do |token|
        User.authenticate_token(token)
      end
    end

    def current_user?
      current_user.present?
    end

    protected

    def not_found
      render json: {
        schemas: [Scim::Shady::Messages::ERROR],
        detail: "Resource #{params[:id]} not found",
        status: "404",
      }.to_json, status: :not_found
    end

    private

    def authenticate!
      render plain: "Unauthorized", status: :unauthorized unless current_user?
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
  end
end
