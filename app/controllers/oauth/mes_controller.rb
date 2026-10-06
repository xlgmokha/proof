# frozen_string_literal: true

module Oauth
  class MesController < ActionController::API
    include BearerAuthentication
    before_action { authenticate_bearer!(scope: required_scope) }

    def show
      render json: @access_token.claims
    end
    alias create show

    private

    def required_scope
      nil
    end
  end
end
