# frozen_string_literal: true

module Oauth
  class TokensController < ActionController::API
    include ClientAuthentication
    include AssertionGrants
    before_action :apply_cache_headers
    before_action :authenticate_client!
    before_action :verify_dpop_proof!, only: :create

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

      ensure_certificate!
      @access_token, @refresh_token = tokens_for(grant_type)
      raise GrantError.new('invalid_grant') if @access_token.nil?

      bind_to_dpop_key(@access_token, @refresh_token)
      bind_to_certificate(@access_token)

      render formats: :json
    rescue StandardError => error
      raise if error.is_a?(GrantError) || error.is_a?(ActiveRecord::RecordNotFound)

      # RFC 6749 Section 5.2 has no code for a fault of the server.
      Rails.logger.error(error)
      render json: { error: 'server_error' }, status: :internal_server_error
    end

    # RFC 7662
    def introspect
      # Section 2.1: only confidential clients may learn about tokens.
      raise GrantError.new('invalid_client', 'Public clients cannot introspect tokens.', status: :unauthorized) if current_client.public_client?

      token = find_token(params[:token], params[:token_type_hint])
      body = token.nil? || token.revoked? || token.expired? ? { active: false } : introspection_for(token)
      return render_introspection_jwt(body) if introspection_jwt_requested?

      render json: body, status: :ok
    end

    # RFC 7009
    def revoke
      token = find_token(params[:token], params[:token_type_hint])
      # Section 2.1: only the client the token was issued to may revoke it. Anything
      # else is answered as an unknown token, so it does not reveal that it exists.
      token.revoke! if token&.issued_to?(current_client)
      render plain: '', status: :ok
    end

    private

    # RFC 9449 Section 5: a proof sent with the request makes the issued tokens
    # sender-constrained to its key.
    def verify_dpop_proof!
      proof = request.headers['DPoP']
      return if proof.blank?

      @dpop_jkt = DpopProof.new(
        proof, method: request.method, url: "#{request.base_url}#{request.path}", nonce_required: DpopNonce.required?
      ).verify!
      response.headers['DPoP-Nonce'] = DpopNonce.current if DpopNonce.required?
    rescue DpopProof::UseNonce => error
      # Section 8: hand out a nonce and let the client try again.
      response.headers['DPoP-Nonce'] = DpopNonce.current
      render_oauth_error(GrantError.new('use_dpop_nonce', error.message))
    rescue DpopProof::Invalid => error
      render_oauth_error(GrantError.new('invalid_dpop_proof', error.message))
    end

    # RFC 8705 Section 3: a client that asked for certificate-bound tokens
    # has to present its certificate.
    def ensure_certificate!
      return unless current_client.tls_client_certificate_bound_access_tokens?
      return if ClientCertificate.from(request)

      raise GrantError.new('invalid_request', 'A client certificate is required.')
    end

    def bind_to_certificate(token)
      return unless current_client.tls_client_certificate_bound_access_tokens?

      token.update_columns(x5t_s256: ClientCertificate.from(request).thumbprint)
    end

    def bind_to_dpop_key(*tokens)
      return if @dpop_jkt.nil?

      tokens.compact.each { |x| x.update_columns(dpop_jkt: @dpop_jkt) if x.dpop_jkt.blank? }
    end

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
    JWT_INTROSPECTION = 'application/token-introspection+jwt'

    # RFC 9701 Section 4: a client asks for a signed response with `Accept`.
    def introspection_jwt_requested?
      request.headers['Accept'].to_s.split(',').any? { |x| x.split(';').first.to_s.strip.casecmp?(JWT_INTROSPECTION) }
    end

    # RFC 9701 Section 5: the usual response is the `token_introspection`
    # claim of a JWT that names the server and the client it is meant for.
    def render_introspection_jwt(body)
      jwt = BearerToken.new.encode(
        { aud: current_client.to_param, token_introspection: body }, typ: 'token-introspection+jwt'
      )
      render plain: jwt, content_type: JWT_INTROSPECTION, status: :ok
    end

    def introspection_for(token)
      claims = token.claims.slice(:scope, :client_id, :exp, :iat, :nbf, :sub, :aud, :iss, :jti, :cnf, :act, :authorization_details, :acr, :auth_time)
      claims[:token_type] = token.dpop_jkt.present? ? 'DPoP' : 'Bearer' if token.access?
      claims[:username] = token.subject.email if token.subject.respond_to?(:email)
      claims.merge(active: true)
    end

    def supported?(grant_type)
      Client::GRANT_TYPES.include?(grant_type)
    end

    # RFC 8707 Section 2.2. Returns nil when none was requested.
    def requested_resource
      value = params[:resource]
      return if value.blank?
      raise GrantError.new('invalid_target', 'Only one resource may be requested.') unless value.is_a?(String)
      raise GrantError.new('invalid_target', 'resource must be an absolute URI without a fragment.') unless ResourceIndicator.valid?(value)

      raise GrantError.new('invalid_target', 'The client may not request this resource.') unless ResourceIndicator.permitted?(current_client, value)

      value
    end

    # RFC 9396 Section 7: details sent to the token endpoint may only narrow
    # what was granted. With no grant to narrow (client credentials), they
    # are checked as they are.
    def authorization_details_for(granted)
      requested = AuthorizationDetails.parse(params[:authorization_details], client: current_client)
      return granted if requested.nil?

      if granted.present? && !AuthorizationDetails.subset?(requested, granted)
        raise GrantError.new('invalid_authorization_details', 'authorization_details exceeds the grant.')
      end

      requested
    rescue AuthorizationDetails::Invalid => error
      raise GrantError.new('invalid_authorization_details', error.message)
    end

    # RFC 6749 Section 3.3
    def requested_scope
      Scopes.resolve(params[:scope], allowed: current_client.allowed_scopes) || raise(GrantError.new('invalid_scope'))
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
        # OAuth 2.1 "Reuse of Authorization Codes": a replay that does not even
        # present the right parameters does not revoke what was issued.
        replayed = :invalid if replayed && !valid_replay?(authorization)
        next if replayed

        verify_code!(authorization)
        authorization.issue_tokens_to(
          current_client, resource: resource_for(authorization.resource),
          authorization_details: authorization_details_for(authorization.authorization_details)
        )
      end
      return tokens unless replayed

      # Outside of the lock's transaction, so the revocation is not rolled back.
      authorization.revoke_tokens! unless replayed == :invalid
      raise GrantError.new('invalid_grant', 'The authorization code was already used.')
    end

    def valid_replay?(authorization)
      redirect_ok = authorization.redirect_uri_matches?(params[:redirect_uri])
      redirect_ok && authorization.challenge.present? && authorization.valid_verifier?(params[:code_verifier])
    end

    def verify_code!(authorization)
      if authorization.expired_at <= Time.current
        raise GrantError.new('invalid_grant', 'The authorization code has expired.')
      end
      unless authorization.redirect_uri_matches?(params[:redirect_uri])
        raise GrantError.new('invalid_grant', 'redirect_uri does not match the authorization request.')
      end
      # RFC 9449 Section 10: a code bound to a key is only good with a proof from it.
      if authorization.dpop_jkt.present? && authorization.dpop_jkt != @dpop_jkt
        raise GrantError.new('invalid_dpop_proof', 'The authorization code is bound to a different key.')
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
        # RFC 9449 Section 5: a bound refresh token needs a proof from the same key.
        if token.dpop_jkt.present? && token.dpop_jkt != @dpop_jkt
          raise GrantError.new('invalid_dpop_proof', 'The refresh token is bound to a different key.')
        end

        token.issue_tokens_to(
          current_client, scope: narrowed_scope(token), resource: resource_for(token.resource),
          authorization_details: authorization_details_for(token.authorization_details)
        )
      end
      return tokens unless replayed

      token.revoke_family!
      raise GrantError.new('invalid_grant', 'The refresh token was already used.')
    end

    # RFC 8707 Section 2.2: a resource requested at the token endpoint may not
    # widen what the grant was for.
    def resource_for(granted)
      requested = requested_resource
      return granted if requested.nil?
      raise GrantError.new('invalid_target', 'resource does not match the grant.') if granted.present? && granted != requested

      requested
    end

    # The scope of a refreshed token may not exceed the original grant.
    def narrowed_scope(token)
      return token.scope if params[:scope].blank?

      requested = Scopes.parse(params[:scope]).uniq
      raise GrantError.new('invalid_scope') unless Scopes.subset?(requested, token.scopes)

      Scopes.format(requested)
    end

    # RFC 8628 Section 3.4 and 3.5. The outcome is decided inside the lock and
    # raised outside of it, so the bookkeeping of a poll is not rolled back.
    def device_code_grant
      raise GrantError.new('invalid_request', 'device_code is required.') if params[:device_code].blank?

      request = DeviceAuthorization.find_by_device_code(params[:device_code], current_client)
      raise GrantError.new('invalid_grant', 'The device_code is not valid.') if request.nil?

      outcome = request.with_lock { poll_device_authorization(request) }
      return outcome unless outcome.is_a?(Symbol)

      raise GrantError.new(outcome.to_s)
    end

    def poll_device_authorization(request)
      return :expired_token if request.expired?
      return :access_denied if request.denied?

      too_fast = request.polled_too_fast?
      request.record_poll!(slow_down: too_fast)
      return :slow_down if too_fast
      return :authorization_pending if request.pending?

      tokens = request.user.issue_tokens_to(current_client, scope: request.scope, resource: request.resource)
      request.destroy!
      tokens
    end

    # RFC 8693 Section 2.1
    def token_exchange_grant
      exchange = TokenExchange.new(
        current_client,
        subject_token: params[:subject_token], subject_token_type: params[:subject_token_type],
        actor_token: params[:actor_token], actor_token_type: params[:actor_token_type],
        requested_token_type: params[:requested_token_type],
        scope: params[:scope], audience: params[:audience], resource: requested_resource, dpop_jkt: @dpop_jkt
      )
      @issued_token_type = TokenExchange::ACCESS_TOKEN_TYPE
      [exchange.call, nil]
    rescue TokenExchange::Invalid => error
      raise GrantError.new(error.error, error.message)
    end

    def client_credentials_grant
      raise GrantError.new('unauthorized_client') if current_client.public_client?

      [
        current_client.access_token(
          scope: Scopes.format(requested_scope), resource: requested_resource,
          authorization_details: authorization_details_for(nil)
        ),
        nil
      ]
    end

    def tokens_for(grant_type = params[:grant_type])
      case grant_type
      when 'authorization_code'
        authorization_code_grant
      when 'refresh_token'
        refresh_grant
      when 'client_credentials'
        client_credentials_grant
      when DeviceAuthorization::GRANT_TYPE # RFC8628
        device_code_grant
      when TokenExchange::GRANT_TYPE # RFC8693
        token_exchange_grant
      when AssertionGrants::SAML_BEARER_GRANT # RFC7522
        saml_assertion_grant(params[:assertion], Scopes.format(requested_scope), requested_resource)
      when AssertionGrants::JWT_BEARER_GRANT # RFC7523
        jwt_bearer_grant(params[:assertion], Scopes.format(requested_scope), requested_resource)
      end
    end
  end
end
