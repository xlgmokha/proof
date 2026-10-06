# frozen_string_literal: true

module Oauth
  class ClientsController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
    before_action :apply_cache_headers
    before_action :authenticate!, except: [:create]

    def show
      render status: :ok, formats: :json
    end

    def create
      @client = Client.create!(transform(secure_params))
      @registration_access_token = @client.access_token.to_jwt
      render status: :created, formats: :json
    rescue ActiveRecord::RecordInvalid => error
      json = {
        error: error_type_for(error.record.errors),
        error_description: error.record.errors.full_messages.join(' ')
      }
      render json: json, status: :bad_request
    end

    def update
      @client = Client.find(params[:id])
      @client.update!(transform(secure_params))
      render status: :ok, formats: :json
    rescue ActiveRecord::RecordInvalid => error
      json = {
        error: error_type_for(error.record.errors),
        error_description: error.record.errors.full_messages.join(' ')
      }
      render json: json, status: :bad_request
    end

    # RFC 7592 Section 2.3
    def destroy
      @client.destroy!
      head :no_content
    end

    private

    def authenticate!
      token = authenticate_with_http_token do |jwt, _options|
        claims = Token.claims_for(jwt)
        next if claims.empty? || Token.revoked?(claims[:jti])

        @registration_access_token = jwt
        Token.find(claims[:jti])
      end
      return request_http_token_authentication if token.blank?

      unless Client.where(id: params[:id]).exists?
        token.revoke!
        return render json: {}, status: :unauthorized
      end
      return render json: {}, status: :forbidden unless token.subject.to_param == params[:id]

      @client = token.subject
    end

    def secure_params
      params.permit(
        :client_name,
        :token_endpoint_auth_method,
        :logo_uri,
        :jwks_uri,
        jwks: {},
        redirect_uris: []
      )
    end

    def transform(params)
      {
        name: params[:client_name],
        redirect_uris: params[:redirect_uris],
        token_endpoint_auth_method: params.fetch(:token_endpoint_auth_method, 'client_secret_basic'),
        logo_uri: params[:logo_uri],
        jwks_uri: params[:jwks_uri],
        jwks: params[:jwks].presence&.to_h,
      }
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
