# frozen_string_literal: true

module Oauth
  class MetadataController < ActionController::API
    # RFC 8414 Section 3.1: the document is found by inserting the well-known
    # segment into the issuer, so only that path serves it.
    def show
      expected = URI.parse(Oauth::Issuer.identifier.to_s).path
      return head :not_found unless "/#{params[:path]}".chomp('/').then { |x| x == '/' ? '' : x } == expected.chomp('/')

      render formats: :json
    end
  end
end
