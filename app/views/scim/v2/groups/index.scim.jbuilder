# frozen_string_literal: true

json.schemas [Scim::Kit::V2::Messages::LIST_RESPONSE]
json.totalResults @groups.total_count
json.startIndex @groups.page + 1
json.itemsPerPage @groups.page_size
json.Resources do
  json.array! @groups do |group|
    json.partial! group, as: :group
  end
end
