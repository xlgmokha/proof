# frozen_string_literal: true

# An error response of the token endpoint (RFC 6749 Section 5.2).
class GrantError < StandardError
  attr_reader :error, :status

  def initialize(error, description = nil, status: :bad_request)
    # RFC 6749 Section 5.2: only %x20-21, %x23-5B and %x5D-7E are allowed.
    description = description&.gsub(/[^\x20\x21\x23-\x5B\x5D-\x7E]/, '')
    super(description || error)
    @error = error
    @description = description
    @status = status
  end

  attr_reader :description
end
