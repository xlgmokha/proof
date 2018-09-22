class PasswordAuthentication < Authentication
  def authenticate(password)
    user.authenticate(password)
  end
end
