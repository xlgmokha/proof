# frozen_string_literal: true

module Pageable
  extend ActiveSupport::Concern

  included do
    def paginate(query)
      Paginate.new(query, params)
    end
  end
end
