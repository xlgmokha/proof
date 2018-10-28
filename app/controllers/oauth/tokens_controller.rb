# frozen_string_literal: true

module Oauth
  class TokensController < ApplicationController
    protect_from_forgery with: :null_session

    def create
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'

      @access_token, @refresh_token = tokens_for(params[:grant_type])
      return bad_request if @access_token.nil?

      render formats: :json
    rescue StandardError => error
      Rails.logger.error(error)
      bad_request
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
        Client.find(id)&.authenticate(client_secret)
      end
      return if current_client

      render "invalid_client", formats: :json, status: :unauthorized
    end

    def bad_request
      render "bad_request", formats: :json, status: :bad_request
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

    def saml_assertion_grant(raw)
      assertion = Saml::Kit::Assertion.new(
        Base64.urlsafe_decode64(raw)
      )
      return if assertion.invalid?

      user = if assertion.name_id_format == Saml::Kit::Namespaces::PERSISTENT
               User.find(assertion.name_id)
             else
               User.find_by!(email: assertion.name_id)
             end
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
      when 'urn:ietf:params:oauth:grant-type:saml2-bearer' # RFC7522
        saml_assertion_grant(params[:assertion])
        # when 'urn:ietf:params:oauth:grant-type:jwt-bearer' # RFC7523
        # raise NotImplementedError
      end
    end
  end
end
