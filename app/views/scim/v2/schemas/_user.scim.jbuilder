# frozen_string_literal: true

json.id SCIM::Schema::USER
json.meta do
  json.resourceType "Schema"
  json.location scim_v2_schema_url(id: SCIM::Schema::USER)
end
json.name "User"
json.description "User Account"
json.attributes [
  {
    "name": "userName",
    "type": "string",
    "multiValued": false,
    "description": "Unique identifier for the User",
    "required": true,
    "caseExact": false,
    "mutability": "readWrite",
    "returned": "default",
    "uniqueness": "server"
  },
  {
    "name": "password",
    "type": "string",
    "multiValued": false,
    "description": "The User's cleartext password.",
    "required": false,
    "caseExact": false,
    "mutability": "writeOnly",
    "returned": "never",
    "uniqueness": "none"
  },
  {
    "name": "emails",
    "type": "complex",
    "multiValued": true,
    "description": "Email addresses for the user.",
    "required": false,
    "subAttributes": [
      {
        "name": "value",
        "type": "string",
        "multiValued": false,
        "description": "Email addresses for the user.",
        "required": false,
        "caseExact": false,
        "mutability": "readWrite",
        "returned": "default",
        "uniqueness": "none"
      },
      {
        "name": "primary",
        "type": "boolean",
        "multiValued": false,
        "description": "A Boolean value indicating the preferred email",
        "required": false,
        "mutability": "readWrite",
        "returned": "default"
      }
    ],
    "mutability": "readWrite",
    "returned": "default",
    "uniqueness": "none"
  },
  {
    "name": "groups",
    "type": "complex",
    "multiValued": true,
    "description": "A list of groups to which the user belongs.",
    "required": false,
    "subAttributes": [
      {
        "name": "value",
        "type": "string",
        "multiValued": false,
        "description": "The identifier of the User's group.",
        "required": false,
        "caseExact": false,
        "mutability": "readOnly",
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
        "description": "The URI of the corresponding 'Group' resource.",
        "required": false,
        "caseExact": false,
        "mutability": "readOnly",
        "returned": "default",
        "uniqueness": "none"
      },
      {
        "name": "display",
        "type": "string",
        "multiValued": false,
        "description": "A human-readable name.",
        "required": false,
        "caseExact": false,
        "mutability": "readOnly",
        "returned": "default",
        "uniqueness": "none"
      }
    ],
    "mutability": "readOnly",
    "returned": "default"
  }
]
