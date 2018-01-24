module Scim
  class Controller < ApplicationController
    protect_from_forgery with: :null_session
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    private

    def authenticate!
    end

    def not_found
      render json: {
        schemas: [Scim::Shady::Messages::ERROR],
        detail: "Resource #{params[:id]} not found",
        status: "404",
      }.to_json, status: :not_found
    end
  end
end
