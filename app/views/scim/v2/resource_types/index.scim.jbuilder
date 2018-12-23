# frozen_string_literal: true

json.array! @resource_types do |resource_type|
  json.partial! resource_type.to_s
end
