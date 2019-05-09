# frozen_string_literal: true

json.schemas [Scim::Kit::V2::Messages::LIST_RESPONSE]
json.totalResults @total
json.startIndex @page
json.itemsPerPage @page_size
json.Resources do
  json.array! @users do |user|
    json.partial! user, as: :user
  end
end
