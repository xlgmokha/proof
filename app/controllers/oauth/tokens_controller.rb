# frozen_string_literal: true

module Oauth
  class TokensController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include AssertionGrants
    before_action :authenticate!

    def create
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'

      grant_type = params[:grant_type]
      return bad_request if grant_type.blank?
      return bad_request('unsupported_grant_type') unless supported?(grant_type)

      @access_token, @refresh_token = tokens_for(grant_type)
      return bad_request('invalid_grant') if @access_token.nil?

      render formats: :json
    rescue StandardError => error
      Rails.logger.error(error)
      bad_request('invalid_grant')
    end

    def introspect
      claims = Token.claims_for(params[:token], token_type: :any)
      if claims.empty? || Token.revoked?(claims[:jti])
        render json: { active: false }, status: :ok
      else
        render json: claims.merge(active: true), status: :ok
      end
    end

    def revoke
      claims = Token.claims_for(params[:token], token_type: :any)
      current_client.revoke(Token.find(claims[:jti])) unless claims.empty?
      render plain: "", status: :ok
    rescue StandardError => error
      logger.error(error)
      render plain: "", status: :ok
    end

    private

    attr_reader :current_client

    def authenticate!
      @current_client = authenticate_with_http_basic do |id, client_secret|
        Client.find_by(id: id)&.authenticate(client_secret)
      end
      @current_client ||= authenticate_with_post_body
      return if current_client

      response.headers['WWW-Authenticate'] = 'Basic realm="oauth"'
      render "invalid_client", formats: :json, status: :unauthorized
    end

    # RFC 6749 Section 2.3.1: only for clients registered with client_secret_post
    def authenticate_with_post_body
      return if request.authorization.present? || params[:client_id].blank?

      client = Client.find_by(id: params[:client_id])
      return unless client&.client_secret_post?

      client.authenticate(params[:client_secret].to_s)
    end

    def bad_request(error = 'invalid_request')
      @error = error
      render "bad_request", formats: :json, status: :bad_request
    end

    def supported?(grant_type)
      Client::GRANT_TYPES.include?(grant_type)
    end

    def authorization_code_grant(code, verifier)
      authorization = current_client.authorizations.active.find_by!(code: code)
      return unless authorization.valid_verifier?(verifier)

      authorization.issue_tokens_to(current_client)
    end

    def refresh_grant(refresh_token)
      jti = Token.claims_for(refresh_token, token_type: :refresh)[:jti]
      token = Token.find(jti)
      token.issue_tokens_to(current_client)
    end

    def password_grant(username, password)
      user = User.login(username, password)
      user.issue_tokens_to(current_client)
    end

    def tokens_for(grant_type = params[:grant_type])
      case grant_type
      when 'authorization_code'
        authorization_code_grant(params[:code], params[:code_verifier])
      when 'refresh_token'
        refresh_grant(params[:refresh_token])
      when 'client_credentials'
        [current_client.access_token, nil]
      when 'password'
        password_grant(params[:username], params[:password])
      when AssertionGrants::SAML_BEARER_GRANT # RFC7522
        saml_assertion_grant(params[:assertion])
      when AssertionGrants::JWT_BEARER_GRANT # RFC7523
        jwt_bearer_grant(params[:assertion])
      end
    end
  end
end
