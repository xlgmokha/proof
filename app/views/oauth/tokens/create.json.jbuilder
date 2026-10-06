# frozen_string_literal: true

json.access_token @access_token.to_jwt
json.token_type @access_token.dpop_jkt.present? ? 'DPoP' : 'Bearer'
json.expires_in [(@access_token.expired_at - Time.current).ceil, 0].max
json.scope @access_token.scope if @access_token.scope.present?
json.refresh_token(@refresh_token.to_jwt) if @refresh_token.present?
