# frozen_string_literal: true

json.schemas ["urn:ietf:params:scim:api:messages:2.0:Error"]
json.scimType scim_type_for(@error)
json.detail @model.errors.full_messages.join('. ')
json.status "400"
