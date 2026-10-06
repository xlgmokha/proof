# frozen_string_literal: true

module Scim
  # Applies SCIM PATCH operations to a ::User.
  class UserPatch
    SCALARS = { 'username' => :email, 'locale' => :locale, 'timezone' => :timezone }.freeze
    READ_ONLY = %w[id meta groups].freeze

    def initialize(user, actor: Current.user)
      @user = user
      @actor = actor
    end

    # Applies the whole patch or none of it.
    def apply(patch)
      ::User.transaction do
        patch.apply_to(self)
        @user.save!
      end
      @user
    end

    def add(path, value)
      replace(path, value)
    end

    def replace(path, value)
      attribute = path.attribute
      if SCALARS.key?(attribute)
        assign(SCALARS[attribute], string_from(value, path))
      elsif attribute == 'password'
        assign_password(string_from(value, path))
      elsif attribute == 'emails'
        assign(:email, email_from(path, value))
      else
        unsupported!(path)
      end
    end

    def remove(path)
      attribute = path.attribute
      if %w[locale timezone].include?(attribute)
        assign(SCALARS[attribute], nil)
      elsif SCALARS.key?(attribute) || %w[password emails].include?(attribute)
        raise Scim::Error.mutability("#{path.attribute} is required and cannot be removed")
      else
        unsupported!(path)
      end
    end

    private

    def assign(attribute, value)
      @user.public_send("#{attribute}=", value)
    end

    def assign_password(value)
      raise Scim::Error.mutability(I18n.t('scim.errors.user.password_update_not_permitted')) unless @actor == @user

      assign(:password, value)
    end

    def string_from(value, path)
      return value if value.is_a?(String)

      raise Scim::Error.invalid_value("#{path.attribute} must be a string")
    end

    # The user's single email is exposed as both userName and emails[0].value.
    def email_from(path, value)
      return string_from(value, path) if path.sub_attribute == 'value'
      raise Scim::Error.invalid_path('Unsupported path') if path.sub_attribute

      emails = Array.wrap(value)
      raise Scim::Error.invalid_value('emails must be a list of objects') unless emails.all?(Hash)

      primary = emails.find { |x| x['primary'] } || emails.first
      string_from(primary&.dig('value'), path)
    end

    def unsupported!(path)
      raise Scim::Error.mutability("#{path.attribute} is read-only") if READ_ONLY.include?(path.attribute)

      raise Scim::Error.invalid_path("Unsupported attribute: #{path.attribute}")
    end
  end
end
