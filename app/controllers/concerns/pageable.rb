# frozen_string_literal: true

module Pageable
  extend ActiveSupport::Concern

  included do
    def paginate(query, page: 0, page_size: 25)
      Paginate.new(query, page: page, page_size: page_size)
    end

    def page_param(key, default:, bottom: 0, top: 250)
      actual = params.fetch(key, default).to_i
      return bottom if actual < bottom
      return top if actual > top
      actual
    end
  end
end
