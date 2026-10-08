# frozen_string_literal: true

module Scim
  # Applies SCIM PATCH operations to a ::Group.
  class GroupPatch
    def initialize(group)
      @group = group
    end

    # Applies the whole patch or none of it.
    def apply(patch)
      ::Group.transaction do
        patch.apply_to(self)
        @group.save!
      end
      @group.reload
    end

    def add(path, value)
      case path.attribute
      when 'displayname' then replace(path, value)
      when 'members' then add_members(path, value)
      else unsupported!(path)
      end
    end

    def replace(path, value)
      case path.attribute
      when 'displayname'
        raise Scim::Error.invalid_value('displayName must be a string') unless value.is_a?(String)

        @group.display_name = value
      when 'members' then replace_members(path, value)
      else unsupported!(path)
      end
    end

    def remove(path)
      case path.attribute
      when 'members' then remove_members(path)
      when 'displayname' then raise Scim::Error.mutability('displayName is required and cannot be removed')
      else unsupported!(path)
      end
    end

    private

    def add_members(path, value)
      ensure_plain_path!(path)
      users_for(value).each do |user|
        @group.group_memberships.find_or_create_by!(user: user)
      end
    end

    def replace_members(path, value)
      ensure_plain_path!(path)
      users = users_for(value)
      @group.group_memberships.where.not(user: users).destroy_all
      users.each { |user| @group.group_memberships.find_or_create_by!(user: user) }
    end

    def remove_members(path)
      memberships = @group.group_memberships.includes(:user).to_a
      if path.filter?
        matching = memberships.select { |x| path.matches?(value: x.user_id) }
        raise Scim::Error.no_target('No member matches the path filter') if matching.empty?

        matching.each(&:destroy!)
      else
        memberships.each(&:destroy!)
      end
    end

    def users_for(value)
      ids = member_ids_from(value)
      users = ::User.where(id: ids).to_a
      missing = ids - users.map(&:id)
      raise Scim::Error.invalid_value("Unknown member: #{missing.first}") if missing.any?

      users
    end

    def member_ids_from(value)
      members = Array.wrap(value)
      raise Scim::Error.invalid_value('members must be a list of objects with a value') unless members.all?(Hash)

      ids = members.map { |x| x.with_indifferent_access[:value] }
      invalid = ids.reject { |x| x.is_a?(String) && x.match?(ApplicationRecord::UUID) }
      raise Scim::Error.invalid_value("Invalid member: #{invalid.first.inspect}") if invalid.any?

      ids
    end

    def ensure_plain_path!(path)
      return unless path.filter? || path.sub_attribute

      raise Scim::Error.invalid_path('members does not support filters or sub-attributes here')
    end

    def unsupported!(path)
      raise Scim::Error.mutability("#{path.attribute} is read-only") if %w[id meta].include?(path.attribute)

      raise Scim::Error.invalid_path("Unsupported attribute: #{path.attribute}")
    end
  end
end
