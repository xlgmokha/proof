# frozen_string_literal: true

json.schemas [Scim::Kit::V2::Messages::LIST_RESPONSE]
json.totalResults @users.total_count
json.startIndex @users.page + 1
json.itemsPerPage @users.page_size
json.Resources do
  json.array! @users do |user|
    json.partial! user, as: :user
  end
end
