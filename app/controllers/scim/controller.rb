# frozen_string_literal: true

module Scim
  class Controller < ApplicationController
    protect_from_forgery with: :null_session
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    before_action :apply_scim_content_type

    private

    def current_user
      @current_user ||= authenticate_with_http_token do |token|
        User.authenticate_token(token)
      end
    end

    def authenticate!
      render plain: "Unauthorized", status: :unauthorized unless current_user?
    end

    def not_found
      render json: {
        schemas: [Scim::Shady::Messages::ERROR],
        detail: "Resource #{params[:id]} not found",
        status: "404",
      }.to_json, status: :not_found
    end

    def apply_scim_content_type
      response.headers['Content-Type'] = Mime[:scim].to_s
    end
  end
end
