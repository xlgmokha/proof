# frozen_string_literal: true

module SCIM
  class UserMapper
    def initialize(url_helpers)
      @url_helpers = url_helpers
    end

    def map_from(user)
      schema = SCIM::Schema.user
      x = Scim::Kit::V2::Resource.new(schemas: [schema], location: @url_helpers.scim_v2_user_url(user))
      x.meta.version = user.lock_version
      x.meta.created = user.created_at
      x.meta.last_modified = user.updated_at
      x.id = user.id
      x.user_name = user.email
      x.locale = user.locale
      x.timezone = user.timezone
      x.emails = [{ value: user.email, primary: true }]
      x
    end
  end
end
