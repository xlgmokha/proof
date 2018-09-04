# frozen_string_literal: true

json.array! [
  {
    "schemas": [SCIM::Schema::RESOURCE_TYPE],
    "id": "User",
    "meta": {
      "location": scim_v2_resource_type_url(id: 'User'),
      "resourceType": "ResourceType"
    },
    "description": "User Account",
    "endpoint": scim_v2_users_url,
    "name": "User",
    "schema": SCIM::Schema::USER,
    "schemaExtensions": []
  },
  {
    "schemas": [SCIM::Schema::RESOURCE_TYPE],
    "id": "Group",
    "meta": {
      "location": scim_v2_resource_type_url(id: 'Group'),
      "resourceType": "ResourceType"
    },
    "description": "Group",
    "endpoint": scim_v2_groups_url,
    "name": "Group",
    "schema": SCIM::Schema::GROUP,
    "schemaExtensions": []
  }
]
