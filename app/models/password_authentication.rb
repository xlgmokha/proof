# frozen_string_literal: true

class PasswordAuthentication < Authentication
  def authenticate(password)
    user.authenticate(password)
  end
end
