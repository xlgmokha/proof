# frozen_string_literal: true

# An error response of the token endpoint (RFC 6749 Section 5.2).
class GrantError < StandardError
  attr_reader :error, :status

  def initialize(error, description = nil, status: :bad_request)
    super(description || error)
    @error = error
    @description = description
    @status = status
  end

  attr_reader :description
end
