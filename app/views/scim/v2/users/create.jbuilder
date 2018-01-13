json.schemas [Scim::Shady::Schemas::USER]
json.id @user.id
json.userName @user.email
json.meta do
  json.resourceType "User"
  json.created @user.created_at.iso8601
  json.lastModified @user.updated_at.iso8601
  json.location scim_v2_users_url(@user)
  json.version @user.lock_version
end
