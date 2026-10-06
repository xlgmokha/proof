# OAuth RFCs

Which OAuth specifications this server implements, where, and how each is
tested. Every row names the spec file that encodes the requirements, so a
change that breaks the RFC fails a test.

The RFC texts could not be fetched while this was written (the build
environment blocks the IETF hosts), so the requirements were taken from the
specifications as known, cross-checked against the OAuth 2.1 draft and then
audited by independent reviewers. Treat the specs as the proof of the
interpretation, and correct a spec if the RFC says otherwise.

## Implemented

| RFC | Subject | Code | Tests |
| --- | --- | --- | --- |
| 6749 | OAuth 2.0 core: authorization code, refresh token, client credentials | `Oauth::AuthorizationsController`, `Oauth::TokensController`, `ClientAuthentication` | `spec/requests/oauth/{authorizations,tokens}_spec.rb` |
| 6750 | Bearer tokens, `WWW-Authenticate` challenges | `BearerAuthentication` | `spec/requests/oauth/me_spec.rb` |
| 7009 | Token revocation | `Oauth::TokensController#revoke`, `Token#revoke!` | `spec/requests/oauth/tokens_spec.rb` |
| 7519 / 7515 / 7517 | JWT, JWS, JWK | `BearerToken`, `JwksFetcher` | `spec/models/token_spec.rb`, `spec/models/jwks_fetcher_spec.rb` |
| 7522 | SAML 2.0 bearer grant | `AssertionGrants#saml_assertion_grant` | `spec/requests/oauth/tokens_spec.rb` |
| 7523 | JWT bearer grant and client authentication (`private_key_jwt`) | `JwtBearerAssertion`, `AssertionGrants`, `ClientAuthentication` | `spec/requests/oauth/tokens_spec.rb`, `spec/models/used_assertion_spec.rb` |
| 7591 | Dynamic client registration | `Oauth::ClientsController`, `Client` | `spec/requests/oauth/clients_spec.rb` |
| 7592 | Client registration management | `Oauth::ClientsController` | `spec/requests/oauth/clients_spec.rb` |
| 7636 | PKCE (S256 only, required of every client) | `AuthorizationRequest`, `Authorization` | `spec/requests/oauth/authorizations_spec.rb`, `spec/models/authorization_spec.rb` |
| 7662 | Token introspection | `Oauth::TokensController#introspect` | `spec/requests/oauth/tokens_spec.rb` |
| 8252 | Native apps: loopback redirect with a variable port | `Client#resolve_redirect_uri` | `spec/models/client_spec.rb` |
| 8414 | Authorization server metadata | `app/views/oauth/metadata/show.json.jbuilder` | `spec/requests/well-known/oauth_spec.rb` |
| 8628 | Device authorization grant | `Oauth::DeviceAuthorizationsController`, `Oauth::DevicesController`, `DeviceAuthorization` | `spec/requests/oauth/device_authorizations_spec.rb` |
| 8693 | Token exchange (access, refresh and JWT subject tokens; delegation with `act`) | `TokenExchange` | `spec/requests/oauth/token_exchange_spec.rb` |
| 8705 | Mutual TLS client authentication (`tls_client_auth`, `self_signed_tls_client_auth`) and certificate-bound access tokens | `ClientCertificate`, `ClientAuthentication#authenticate_mtls`, `BearerAuthentication` | `spec/requests/oauth/mutual_tls_spec.rb` |
| 8707 | Resource indicators | `ResourceIndicator`, token and authorization endpoints | `spec/requests/oauth/resource_indicators_spec.rb` |
| 9068 | JWT profile for access tokens (`at+jwt`) | `Token#claims`, `BearerToken` | `spec/models/token_spec.rb` |
| 9101 | JWT-secured authorization requests, by value and by reference (registered `request_uris`) | `RequestObject`, `AuthorizationRequest`, `JwksFetcher#fetch_text` | `spec/requests/oauth/request_objects_spec.rb`, `spec/requests/oauth/request_uri_reference_spec.rb` |
| 9126 | Pushed authorization requests | `Oauth::PushedRequestsController`, `PushedAuthorizationRequest` | `spec/requests/oauth/pushed_authorization_requests_spec.rb` |
| 9207 | `iss` in authorization responses | `Oauth::AuthorizationsController`, `Client#redirect_url_for` | `spec/requests/oauth/authorizations_spec.rb` |
| 9396 | Rich authorization requests (`authorization_details`) | `AuthorizationDetails`, `AuthorizationRequest`, `Oauth::TokensController` | `spec/requests/oauth/authorization_details_spec.rb` |
| 9449 | DPoP, including authorization code binding (`dpop_jkt`) and server-provided nonces | `DpopProof`, `DpopNonce`, `BearerAuthentication`, `Oauth::TokensController` | `spec/requests/oauth/dpop_spec.rb`, `spec/requests/oauth/dpop_binding_spec.rb` |
| 9700 | Security best current practice | see below | across the above |
| 9728 | Protected resource metadata | `Oauth::ResourceMetadataController` | `spec/requests/oauth/protected_resource_metadata_spec.rb` |

SCIM (RFC 7643/7644) is documented with the SCIM API and is not repeated here.

### RFC 9700 checklist

| Section | Requirement | How |
| --- | --- | --- |
| 2.1.1 | PKCE for every authorization code request, S256 | `plain` and a missing challenge are rejected at the authorization and PAR endpoints |
| 2.1.2 | No implicit grant | `token` response type removed |
| 2.4 | No resource owner password credentials grant | grant removed |
| 4.1.3 | Exact redirect URI matching | `Client#resolve_redirect_uri`; only the port of a loopback redirect may vary (RFC 8252) |
| 4.5 | Authorization code single use, tokens revoked on replay | `Oauth::TokensController#authorization_code_grant` |
| 4.14 | Refresh token rotation, family revoked on replay | `Oauth::TokensController#refresh_grant`, `Token#revoke_family!` |
| 4.2 | Mix-up defense | `iss` on every authorization response (RFC 9207) |

## Deliberate choices

- **Issuer.** `Oauth::Issuer.identifier` (`ISSUER`, which is also the SAML entity
  id) is the metadata `issuer`, the `iss` of tokens and of authorization
  responses. Set it to the server's `https` URL without a trailing slash.
- **Refresh tokens are JWTs** (`typ: rt+jwt`), recorded in the database so they
  can be revoked and rotated. Access tokens are `at+jwt`.
- **Revocation is immediate.** Token state is read from the database on every
  request; nothing is cached.
- **One resource per request.** RFC 8707 allows several; a request naming more
  than one is rejected with `invalid_target`.
- **DPoP nonces** are off unless `DPOP_NONCE_REQUIRED=true`; when on, the token endpoint and DPoP resources answer `use_dpop_nonce` and hand out a nonce.
- **Request objects by reference** are only fetched from `https` URLs the client registered as `request_uris`, through the same address-restricted fetcher as `jwks_uri`.
- **Per-client grants.** Clients registered before grant types were stored keep
  the grants they had; newer grants (`device_code`, `token-exchange`) are opt-in
  through registration.
- **Housekeeping.** `rake oauth:purge` removes expired replay records, proofs,
  pushed requests and device authorizations. Run it periodically.

## Audit findings

Independent reviewers audited the code against the RFCs. Fixed: resource
servers verify `aud` (default audience is the issuer, RFC 9068/8707); the
`resource_metadata` challenge names the resource accessed and SCIM sends it
(RFC 9728/6750); public clients cannot introspect (RFC 7662); revocation and
introspection advertise their signing algorithms (RFC 8414); a missing
`response_type` is `invalid_request`, `code_challenge` arrays no longer raise
and must be 43 characters (RFC 6749/7636); loopback redirects reject fragments
and userinfo; `state` is echoed exactly; assertion grants cannot be enabled by
open dynamic registration (RFC 7523); registration access tokens are scoped to
`/oauth/clients` and are no longer revoked by `client_credentials` (RFC 7592);
`redirect_uris` is only required for the authorization code grant; token
exchange returns `invalid_request` for bad subject/actor tokens, keeps DPoP
binding, and cannot widen the target (RFC 8693/9449); a missing `device_code`
is `invalid_request` (RFC 8628); `jwks_uri` fetching refuses mapped, NAT64,
6to4, CGNAT and reserved addresses and non-object key sets.

Also fixed in a second round: token endpoint, PAR and device endpoints
require a form-urlencoded body, reject query-string parameters and repeated
parameters (RFC 6749 Section 3.2); unexpected faults are `server_error` (500);
metadata is served at the issuer-derived well-known path and `ISSUER` is
validated at boot in production (RFC 8414); `none` is the registered name of
the public client method (RFC 7591); `htu` is normalised (RFC 9449); device
user-code entry has a global ceiling as well as a per-user/IP one.

Third round: client assertions use the issuer identifier as their only audience (the RFC 7523bis draft text, read from its source), clients may only name resources they were granted (`Client#resources`, operator set), and device user-code entry is locked out after repeated failures (`FailedDeviceAttempt`). The RFC 9728 and 7523bis drafts were read from their WG sources and agree with the implemented behaviour; the other RFC texts were still unreachable.

Known and left open: none of the reviewer findings remain open.

## Not implemented

| RFC | Why |
| --- | --- |
| 7800 / 8725 | Proof-of-possession key semantics are used through the `cnf` claim (`jkt`, `x5t#S256`); RFC 8725 is best-practice guidance, and its rules that matter (algorithm allow list, `typ`, `iss`, `aud`) are enforced where tokens are verified. |
| 9470 (step-up authentication) | Needs the login to record an authentication context class and time (`acr`, `auth_time`); this application's login does not distinguish authentication strength. |
| 6819 | Obsoleted by RFC 9700. |

## Configuration

| Variable | Effect |
| --- | --- |
| `ISSUER` | The issuer identifier; an `https` URL without query or fragment (validated at boot in production). |
| `DPOP_NONCE_REQUIRED` | `true` to require server-provided DPoP nonces (RFC 9449 Section 8). |
| `AUTHORIZATION_DETAILS_TYPES` | Comma separated `authorization_details` types this server understands (RFC 9396). A client may use those it registered. |
| `MTLS_ENABLED` | `true` to accept client certificates (RFC 8705). |
| `CLIENT_CERT_HEADER` | Header the TLS terminator puts the URL-encoded PEM certificate in (default `X-Client-Cert`). The terminator must verify the handshake and strip this header from outside requests. |
