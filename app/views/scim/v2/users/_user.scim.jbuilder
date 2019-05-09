# frozen_string_literal: true

json.schemas ["urn:ietf:params:scim:schemas:core:2.0:User"]
json.id user.to_param
json.meta do
  json.resourceType 'User'
  json.created user.created_at.iso8601
  json.lastModified user.updated_at.iso8601
  json.version response.headers['ETag']
  json.location scim_v2_user_url(id: user.to_param)
end
json.userName user.email
json.name do
  json.formatted user.email
  json.familyName user.email
  json.givenName user.email
end
json.displayName user.email
json.locale user.locale
json.timezone user.timezone
json.active true
json.emails [{ value: user.email, primary: true }]
json.groups []
