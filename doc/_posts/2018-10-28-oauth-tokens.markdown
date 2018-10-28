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

## Refreshing an Access Token

[Section 6](https://tools.ietf.org/html/rfc6749#section-6)

{% include oauth-tokens-refresh-token.html %}
