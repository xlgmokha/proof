# frozen_string_literal: true

class TotpAuthentication < Authentication
  def authenticate(code)
    user.mfa.authenticate(code) ? user : false
  end
end
