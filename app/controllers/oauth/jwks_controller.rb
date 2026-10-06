# frozen_string_literal: true

module Oauth
  # Publishes the public key used to sign tokens (RFC 7517).
  class JwksController < ActionController::API
    def show
      expires_in 1.hour, public: true
      render json: { keys: [BearerToken.new.jwk.export] }
    end
  end
end
