# frozen_string_literal: true

json.access_token @access_token.to_jwt
json.token_type 'Bearer'
json.expires_in 1.hour.to_i
json.refresh_token @refresh_token.to_jwt
