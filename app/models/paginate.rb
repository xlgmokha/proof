class Paginate < SimpleDelegator
  def initialize(query, params)
    @query = query
    @params = params
    super(records)
  end

  def total_count
    @total_count ||= @query.count
  end

  def page
    @page ||= page_param(:startIndex, default: 1, bottom: 1, top: 100)
  end

  def page_size
    @page_size ||= page_param(:count, default: 25, bottom: 0, top: 25)
  end

  def records
    @records ||= @query.offset(page - 1).limit(page_size)
  end

  private

  def page_param(key, default:, bottom: 0, top: 250)
    actual = @params.fetch(key, default).to_i
    return bottom if actual < bottom
    return top if actual > top
    actual
  end
end
