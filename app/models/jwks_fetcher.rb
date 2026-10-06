# frozen_string_literal: true

require 'net/http'
require 'resolv'

# Fetches a client's JSON Web Key Set from its registered jwks_uri.
#
# The URI is supplied by (untrusted) registrants, so only https is allowed and
# addresses that resolve to private, loopback or link-local ranges are refused.
class JwksFetcher
  class Error < StandardError; end

  MAX_BYTES = 64.kilobytes
  TIMEOUT = 5
  CACHE_TTL = 5.minutes

  def initialize(cache: Rails.cache)
    @cache = cache
  end

  # The client's registered keys, by value or by reference (RFC 7591 Section 2).
  def key_set_for(client)
    set = client.jwks.presence || (client.jwks_uri.present? && fetch(client.jwks_uri))
    raise Error.new('client has no registered keys') if set.blank?
    raise Error.new('the key set is not a JSON object') unless set.is_a?(Hash)

    JWT::JWK::Set.new(set.with_indifferent_access)
  rescue JWT::JWKError => error
    raise Error.new(error.message)
  end

  def fetch(uri)
    @cache.fetch("jwks:#{Digest::SHA256.hexdigest(uri)}", expires_in: CACHE_TTL) do
      download(URI.parse(uri))
    end
  rescue URI::InvalidURIError, JSON::ParserError, SocketError, SystemCallError,
         Timeout::Error, OpenSSL::SSL::SSLError => error
    raise Error.new(error.message)
  end

  # The body served at an https URL a client registered, as text (RFC 9101
  # Section 6.2). The same address restrictions as for key sets apply.
  def fetch_text(uri)
    download(URI.parse(uri), parse: false)
  rescue URI::InvalidURIError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
    raise Error.new(error.message)
  end

  private

  def download(uri, parse: true)
    raise Error.new('jwks_uri must use https') unless uri.is_a?(URI::HTTPS)

    address = safe_address_for(uri.host)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ipaddr = address.to_s
    http.open_timeout = http.read_timeout = TIMEOUT
    http.request(Net::HTTP::Get.new(uri.request_uri, 'Accept' => 'application/json')) do |response|
      raise Error.new("unexpected response #{response.code}") unless response.is_a?(Net::HTTPSuccess)

      body = read_limited(response)
      return parse ? JSON.parse(body) : body
    end
  end

  # Stops reading as soon as the limit is exceeded instead of buffering it all.
  def read_limited(response)
    body = +''
    response.read_body do |chunk|
      body << chunk
      raise Error.new('jwks response is too large') if body.bytesize > MAX_BYTES
    end
    body
  end

  def safe_address_for(host)
    addresses = Resolv.getaddresses(host).map { |x| IPAddr.new(x) }
    raise Error.new("unable to resolve #{host}") if addresses.empty?
    raise Error.new('jwks_uri must not resolve to a private address') if addresses.any? { |x| private?(x) }

    addresses.first
  end

  # IPv4 carried inside IPv6 (mapped, NAT64, 6to4) is judged by the IPv4 address.
  EMBEDDED = [IPAddr.new('64:ff9b::/96'), IPAddr.new('2002::/16')].freeze
  RESERVED = %w[100.64.0.0/10 192.0.0.0/24 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4 ff00::/8].map { |x| IPAddr.new(x) }.freeze

  def private?(address)
    address = address.native if address.ipv6? && address.ipv4_mapped?
    return true if EMBEDDED.any? { |x| x.include?(address) }
    return true if RESERVED.any? { |x| x.include?(address) }

    address.private? || address.loopback? || address.link_local? ||
      IPAddr.new('0.0.0.0/8').include?(address) || IPAddr.new('::/128').include?(address)
  rescue IPAddr::InvalidAddressError
    true
  end
end
