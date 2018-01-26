class UserRepository
  def find!(id)
    map_from(User.find_by!(uuid: id))
  end

  def create!(params)
    password = SecureRandom.hex(32)
    map_from(User.create!(email: params[:userName], password: password))
  end

  def update!(id, params)
    user = User.find_by!(uuid: id)
    user.update!(email: params[:userName])
    map_from(user)
  end

  def destroy!(id)
    User.find_by!(uuid: id).destroy!
  end

  private

  def map_from(user, url = Rails.application.routes.url_helpers)
    Scim::Shady::User.build do |x|
      x.id = user.uuid
      x.username = user.email
      x.created_at = user.created_at
      x.updated_at = user.updated_at
      x.location = url.scim_v2_users_url(user)
      x.version = user.lock_version
      x.emails do |y|
        y.add(user.email, primary: true)
      end
    end
  end
end
