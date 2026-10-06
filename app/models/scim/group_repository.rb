# frozen_string_literal: true

module Scim
  class GroupRepository
    def find!(id)
      ::Group.includes(:users).find(id)
    end

    def create!(params)
      ::Group.transaction do
        group = ::Group.create!(display_name: params[:displayName])
        replace_members(group, params[:members])
        group.reload
      end
    end

    # PUT replaces the whole resource (RFC 7644 Section 3.5.1).
    def update!(id, params)
      ::Group.transaction do
        group = ::Group.find(id)
        group.update!(display_name: params[:displayName])
        replace_members(group, params[:members])
        group.reload
      end
    end

    def patch!(id, patch)
      Scim::GroupPatch.new(::Group.find(id)).apply(patch)
    end

    def destroy!(id)
      ::Group.find(id).destroy!
    end

    private

    def replace_members(group, members)
      patch = Scim::GroupPatch.new(group)
      patch.replace(Scim::Path.parse('members'), Array.wrap(members).map(&:to_h))
    end
  end
end
