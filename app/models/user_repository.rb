class UserRepository
  def find!(id)
    User.find_by!(uuid: id)
  end

  def create!(params)
    password = SecureRandom.hex(32)
    User.create!(email: params[:userName], password: password)
  end

  def update!(id, params)
    user = find!(id)
    user.update!(email: params[:userName])
    user
  end

  def destroy!(id)
    find!(id).destroy!
  end
end
