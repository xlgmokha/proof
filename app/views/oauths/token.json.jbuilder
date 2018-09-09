json.access_token SecureRandom.hex(20)
json.token_type 'access'
json.expires_in 1.hour.to_i
json.refresh_token SecureRandom.hex(20)
