# frozen_string_literal: true

class Paginate < SimpleDelegator
  attr_reader :page, :page_size

  def initialize(query, page:, page_size:)
    @query = query
    @page = page
    @page_size = page_size
    super(records)
  end

  def total_count
    @total_count ||= @query.count
  end

  def records
    @records ||= @query.offset(page).limit(page_size)
  end
end
