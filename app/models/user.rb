class User < ApplicationRecord
  has_secure_password
  validates :email, presence: true, email: true, uniqueness: true

  after_initialize do
    self.uuid = SecureRandom.uuid unless self.uuid
  end

  def name_id_for(name_id_format)
    Saml::Kit::Namespaces::PERSISTENT == name_id_format ? uuid : email
  end

  def assertion_attributes_for(request)
    request.trusted? ? trusted_attributes : {}
  end

  def self.login(email, password)
    return if email.blank? || password.blank?

    user = User.find_by!(email: email)
    user.authenticate(password) ? user : nil
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def to_scim(url_helpers = Rails.application.routes.url_helpers)
    Scim::Shady::User.build do |x|
      x.id = uuid
      x.username = email
      x.created_at = created_at
      x.updated_at = updated_at
      x.location = url_helpers.scim_v2_users_url(self)
      x.version = lock_version
      x.emails do |y|
        y.add(email, primary: true)
      end
    end
  end

  private

  def access_token
    BearerToken.new.encode(id: uuid)
  end

  def trusted_attributes
    {
      id: uuid,
      email: email,
      created_at: created_at,
      access_token: access_token,
    }
  end
end
