---
layout: post
title:  "OAuth 2.0 - Tokens"
date:   2018-10-28 14:00:00 -0700
permalink: /oauth/tokens.html
categories: oauth
---

The Tokens endpoint adheres to [RFC-6749](https://tools.ietf.org/html/rfc6749).

## Authorization Code Grant

```text
    +----------+
    | Resource |
    |   Owner  |
    |          |
    +----------+
        ^
        |
       (B)
    +----|-----+          Client Identifier      +---------------+
    |         -+----(A)-- & Redirection URI ---->|               |
    |  User-   |                                 | Authorization |
    |  Agent  -+----(B)-- User authenticates --->|     Server    |
    |          |                                 |               |
    |         -+----(C)-- Authorization Code ---<|               |
    +-|----|---+                                 +---------------+
      |    |                                         ^      v
     (A)  (C)                                        |      |
      |    |                                         |      |
      ^    v                                         |      |
    +---------+                                      |      |
    |         |>---(D)-- Authorization Code ---------'      |
    |  Client |          & Redirection URI                  |
    |         |                                             |
    |         |<---(E)----- Access Token -------------------'
    +---------+       (w/ Optional Refresh Token)
```
[RFC-6749 Section 4.1](https://tools.ietf.org/html/rfc6749#section-4.1)

{% include oauth-tokens-authorization-code.html %}

## Resource Owner Password Credentials Grant

```text
    +----------+
    | Resource |
    |  Owner   |
    |          |
    +----------+
        v
        |    Resource Owner
       (A) Password Credentials
        |
        v
    +---------+                                  +---------------+
    |         |>--(B)---- Resource Owner ------->|               |
    |         |         Password Credentials     | Authorization |
    | Client  |                                  |     Server    |
    |         |<--(C)---- Access Token ---------<|               |
    |         |    (w/ Optional Refresh Token)   |               |
    +---------+                                  +---------------+
```
[Section 4.3](https://tools.ietf.org/html/rfc6749#section-4.3)

{% include oauth-tokens-password.html %}

## Client Credentials Grant

```text
    +---------+                                  +---------------+
    |         |                                  |               |
    |         |>--(A)- Client Authentication --->| Authorization |
    | Client  |                                  |     Server    |
    |         |<--(B)---- Access Token ---------<|               |
    |         |                                  |               |
    +---------+                                  +---------------+
```
[Section 4.4](https://tools.ietf.org/html/rfc6749#section-4.4)

{% include oauth-tokens-client-credentials.html %}

## SAML Assertion Grant

[RFC-7522](https://tools.ietf.org/html/rfc7522)

{% include oauth-tokens-saml-assertion.html %}

## JWT Bearer Grant

[RFC-7523](https://tools.ietf.org/html/rfc7523)

The client exchanges a JWT it signed for an access token. The client authenticates to the
token endpoint as usual and sends the signed JWT in the `assertion` parameter.

| Claim | Requirement |
| ----- | ----------- |
| `iss` | The `client_id` of the authenticating client. |
| `sub` | The `id` or email of the user the tokens are issued for. |
| `aud` | The token endpoint URL (or the issuer URL). |
| `exp` | Required, at most one hour in the future. |
| `jti` | Optional. When present the assertion can only be used once. |

The JWT must be signed with an asymmetric algorithm (RS*, PS* or ES*) using a key from the client's
registered `jwks` or `jwks_uri`. See [Dynamic Client Registration](/doc/oauth/client-registration.html).

{% include oauth-tokens-jwt-bearer.html %}

## Client Authentication

Clients authenticate with HTTP Basic ([Section 2.3.1](https://tools.ietf.org/html/rfc6749#section-2.3.1)).
Clients registered with `token_endpoint_auth_method` of `client_secret_post` may instead send
`client_id` and `client_secret` in the request body.

## Errors

Errors follow [Section 5.2](https://tools.ietf.org/html/rfc6749#section-5.2): `invalid_request` when
`grant_type` is missing, `unsupported_grant_type`, `invalid_client` (with `WWW-Authenticate`) and
`invalid_grant` when the code, credentials, refresh token or assertion are not valid.

## Refreshing an Access Token

[Section 6](https://tools.ietf.org/html/rfc6749#section-6)

{% include oauth-tokens-refresh-token.html %}
