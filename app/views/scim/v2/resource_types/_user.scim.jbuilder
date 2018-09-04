# frozen_string_literal: true

json.schemas [SCIM::Schema::RESOURCE_TYPE]
json.id "User"
json.meta do
  json.location scim_v2_resource_type_url(id: 'User')
  json.resourceType "ResourceType"
end
json.description "User Account"
json.endpoint scim_v2_users_url
json.name "User"
json.schema SCIM::Schema::USER
json.schemaExtensions []
