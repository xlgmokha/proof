# frozen_string_literal: true

json.schemas [SCIM::Schema::RESOURCE_TYPE]
json.id "Group"
json.meta do
  json.location scim_v2_resource_type_url(id: 'Group')
  json.resourceType "ResourceType"
end
json.description "Group"
json.endpoint scim_v2_groups_url
json.name "Group"
json.schema SCIM::Schema::GROUP
json.schemaExtensions []
