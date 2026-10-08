# frozen_string_literal: true

json.schemas [Scim::Kit::V2::Schemas::GROUP]
json.id group.to_param
json.meta do
  json.resourceType 'Group'
  json.created group.created_at.iso8601
  json.lastModified group.updated_at.iso8601
  json.version "W/\"#{group.lock_version}\""
  json.location scim_v2_group_url(id: group.to_param)
end
json.displayName group.display_name
json.members group.users do |user|
  json.value user.to_param
  json.set! '$ref', scim_v2_user_url(id: user.to_param)
  json.type 'User'
  json.display user.email
end
