class UserMapper
  def initialize(url = Rails.application.routes.url_helpers)
    @url = url
  end

  def map_from(user)
    Scim::Shady::User.build do |x|
      x.id = user.uuid
      x.username = user.email
      x.created_at = user.created_at
      x.updated_at = user.updated_at
      x.location = @url.scim_v2_users_url(user)
      x.version = user.lock_version
      x.emails do |y|
        y.add(user.email, primary: true)
      end
    end
  end
end
