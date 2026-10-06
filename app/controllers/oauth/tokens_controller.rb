# frozen_string_literal: true

module Oauth
  class TokensController < ActionController::API
    include ClientAuthentication
    include AssertionGrants
    before_action :apply_cache_headers
    before_action :authenticate_client!

    rescue_from GrantError, with: :render_oauth_error
    rescue_from ActiveRecord::RecordNotFound do
      render_oauth_error(GrantError.new('invalid_grant'))
    end

    # RFC 6749 Section 5
    def create
      grant_type = params[:grant_type]
      raise GrantError.new('invalid_request', 'grant_type is required.') if grant_type.blank?
      raise GrantError.new('unsupported_grant_type') unless supported?(grant_type)
      raise GrantError.new('unauthorized_client') unless current_client.grant_type?(grant_type)

      @access_token, @refresh_token = tokens_for(grant_type)
      raise GrantError.new('invalid_grant') if @access_token.nil?

      render formats: :json
    rescue StandardError => error
      raise if error.is_a?(GrantError) || error.is_a?(ActiveRecord::RecordNotFound)

      Rails.logger.error(error)
      render_oauth_error(GrantError.new('invalid_grant'))
    end

    # RFC 7662
    def introspect
      token = find_token(params[:token], params[:token_type_hint])
      if token.nil? || token.revoked? || token.expired?
        render json: { active: false }, status: :ok
      else
        render json: introspection_for(token), status: :ok
      end
    end

    # RFC 7009
    def revoke
      token = find_token(params[:token], params[:token_type_hint])
      if token && !token.issued_to?(current_client)
        raise GrantError.new('invalid_request', 'The token was not issued to this client.')
      end

      token&.revoke!
      render plain: '', status: :ok
    end

    private

    def apply_cache_headers
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'
    end

    # RFC 7009 Section 2.1 and RFC 7662 Section 2.1: the hint only says where
    # to look first.
    def find_token(jwt, hint)
      raise GrantError.new('invalid_request', 'token is required.') if jwt.blank?

      order = hint == 'refresh_token' ? %i[refresh access] : %i[access refresh]
      order.each do |type|
        token = Token.from_jwt(jwt, token_type: type)
        return token if token
      end
      nil
    end

    # RFC 7662 Section 2.2
    def introspection_for(token)
      claims = token.claims.slice(:scope, :client_id, :exp, :iat, :nbf, :sub, :aud, :iss, :jti, :cnf)
      claims[:token_type] = 'Bearer' if token.access?
      claims[:username] = token.subject.email if token.subject.respond_to?(:email)
      claims.merge(active: true)
    end

    def supported?(grant_type)
      Client::GRANT_TYPES.include?(grant_type)
    end

    # RFC 6749 Section 3.3
    def requested_scope
      Scopes.resolve(params[:scope]) || raise(GrantError.new('invalid_scope'))
    end

    # RFC 6749 Section 4.1.3. A code is single use; presenting it again is
    # taken as a sign that it was stolen, so what was issued from it is revoked.
    def authorization_code_grant
      raise GrantError.new('invalid_request', 'code is required.') if params[:code].blank?

      authorization = current_client.authorizations.find_by(code: params[:code].to_s)
      raise GrantError.new('invalid_grant', 'The authorization code is not valid.') if authorization.nil?

      replayed = false
      tokens = authorization.with_lock do
        replayed = authorization.revoked?
        next if replayed

        verify_code!(authorization)
        authorization.issue_tokens_to(current_client)
      end
      return tokens unless replayed

      # Outside of the lock's transaction, so the revocation is not rolled back.
      authorization.revoke_tokens!
      raise GrantError.new('invalid_grant', 'The authorization code was already used.')
    end

    def verify_code!(authorization)
      if authorization.expired_at <= Time.current
        raise GrantError.new('invalid_grant', 'The authorization code has expired.')
      end
      unless authorization.redirect_uri_matches?(params[:redirect_uri])
        raise GrantError.new('invalid_grant', 'redirect_uri does not match the authorization request.')
      end
      return if authorization.challenge.present? && authorization.valid_verifier?(params[:code_verifier])

      raise GrantError.new('invalid_grant', 'The code_verifier is not valid.')
    end

    # RFC 6749 Section 6, with refresh token rotation and replay detection
    # (RFC 9700 Section 4.14).
    def refresh_grant
      raise GrantError.new('invalid_request', 'refresh_token is required.') if params[:refresh_token].blank?

      token = Token.from_jwt(params[:refresh_token], token_type: :refresh)
      raise GrantError.new('invalid_grant', 'The refresh token is not valid.') unless token&.issued_to?(current_client)

      replayed = false
      tokens = token.with_lock do
        replayed = token.revoked?
        next if replayed

        raise GrantError.new('invalid_grant', 'The refresh token has expired.') if token.expired?

        token.issue_tokens_to(current_client, scope: narrowed_scope(token))
      end
      return tokens unless replayed

      token.revoke_family!
      raise GrantError.new('invalid_grant', 'The refresh token was already used.')
    end

    # The scope of a refreshed token may not exceed the original grant.
    def narrowed_scope(token)
      return token.scope if params[:scope].blank?

      requested = Scopes.parse(params[:scope]).uniq
      raise GrantError.new('invalid_scope') unless Scopes.subset?(requested, token.scopes)

      Scopes.format(requested)
    end

    def client_credentials_grant
      raise GrantError.new('unauthorized_client') if current_client.public_client?

      [current_client.access_token(scope: Scopes.format(requested_scope)), nil]
    end

    def tokens_for(grant_type = params[:grant_type])
      case grant_type
      when 'authorization_code'
        authorization_code_grant
      when 'refresh_token'
        refresh_grant
      when 'client_credentials'
        client_credentials_grant
      when AssertionGrants::SAML_BEARER_GRANT # RFC7522
        saml_assertion_grant(params[:assertion], Scopes.format(requested_scope))
      when AssertionGrants::JWT_BEARER_GRANT # RFC7523
        jwt_bearer_grant(params[:assertion], Scopes.format(requested_scope))
      end
    end
  end
end
