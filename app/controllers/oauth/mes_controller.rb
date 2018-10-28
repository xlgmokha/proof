# frozen_string_literal: true

module Oauth
  class MesController < ApplicationController
    def show
      render json: @claims
    end

    private

    def authenticate!
      @claims = authenticate_with_http_token do |token, _options|
        claims = Token.claims_for(token)
        Token.revoked?(claims[:jti]) ? nil : claims
      end
      request_http_token_authentication if @claims.nil? || @claims.empty?
    end
  end
end
