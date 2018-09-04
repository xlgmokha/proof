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
    "description": "Unique identifier for the User, typically used by the user to directly authenticate to the service provider.  Each User MUST include a non-empty userName value.  This identifier MUST be unique across the service provider's entire set of Users.  REQUIRED.",
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
    "description": "The User's cleartext password.  This attribute is intended to be used as a means to specify an initial password when creating a new User or to reset an existing User's password.",
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
    "description": "Email addresses for the user.  The value SHOULD be canonicalized by the service provider, e.g., 'bjensen@example.com' instead of 'bjensen@EXAMPLE.COM'.  Canonical type values of 'work', 'home', and 'other'.",
    "required": false,
    "subAttributes": [
      {
        "name": "value",
        "type": "string",
        "multiValued": false,
        "description": "Email addresses for the user.  The value SHOULD be canonicalized by the service provider, e.g., 'bjensen@example.com' instead of 'bjensen@EXAMPLE.COM'.  Canonical type values of 'work', 'home', and 'other'.",
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
        "description": "A Boolean value indicating the 'primary' or preferred attribute value for this attribute, e.g., the preferred mailing address or primary email address.  The primary attribute value 'true' MUST appear no more than once.",
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
    "description": "A list of groups to which the user belongs, either through direct membership, through nested groups, or dynamically calculated.",
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
        "description": "The URI of the corresponding 'Group' resource to which the user belongs.",
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
        "description": "A human-readable name, primarily used for display purposes.  READ-ONLY.",
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
