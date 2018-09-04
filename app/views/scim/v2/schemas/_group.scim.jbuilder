# frozen_string_literal: true

json.id SCIM::Schema::GROUP
json.meta do
  json.resourceType "Schema"
  json.location scim_v2_schema_url(id: SCIM::Schema::GROUP)
end
json.name "Group"
json.description "Group"
json.attributes [
  {
    "name": "displayName",
    "type": "string",
    "multiValued": false,
    "description": "A human-readable name for the Group.",
    "required": false,
    "caseExact": false,
    "mutability": "readWrite",
    "returned": "default",
    "uniqueness": "none"
  },
  {
    "name": "members",
    "type": "complex",
    "multiValued": true,
    "description": "A list of members of the Group.",
    "required": false,
    "subAttributes": [
      {
        "name": "value",
        "type": "string",
        "multiValued": false,
        "description": "Identifier of the member of this Group.",
        "required": false,
        "caseExact": false,
        "mutability": "immutable",
        "returned": "default",
        "uniqueness": "none"
      },
      {
        "name": "$ref",
        "type": "reference",
        "referenceTypes": %w[
          User
          Group
        ],
        "multiValued": false,
        "description": "The URI corresponding to a SCIM resource.",
        "required": false,
        "caseExact": false,
        "mutability": "immutable",
        "returned": "default",
        "uniqueness": "none"
      },
      {
        "name": "type",
        "type": "string",
        "multiValued": false,
        "description": "A label indicating the type of resource",
        "required": false,
        "caseExact": false,
        "canonicalValues": %w[
          User
          Group
        ],
        "mutability": "immutable",
        "returned": "default",
        "uniqueness": "none"
      }
    ],
    "mutability": "readWrite",
    "returned": "default"
  }
]
