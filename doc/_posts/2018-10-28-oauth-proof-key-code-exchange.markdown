---
layout: post
title:  "OAuth 2.0 - Proof Key Code Exchange"
date:   2018-10-28 14:00:00 -0700
permalink: /oauth/client-proof-key-code-exchange.html
categories: oauth
---

This endpoint adhears Proof Key Code Exchange described in [RFC-7636](https://tools.ietf.org/html/rfc7636).

```text
                                                 +-------------------+
                                                 |   Authz Server    |
       +--------+                                | +---------------+ |
       |        |--(A)- Authorization Request ---->|               | |
       |        |       + t(code_verifier), t_m  | | Authorization | |
       |        |                                | |    Endpoint   | |
       |        |<-(B)---- Authorization Code -----|               | |
       |        |                                | +---------------+ |
       | Client |                                |                   |
       |        |                                | +---------------+ |
       |        |--(C)-- Access Token Request ---->|               | |
       |        |          + code_verifier       | |    Token      | |
       |        |                                | |   Endpoint    | |
       |        |<-(D)------ Access Token ---------|               | |
       +--------+                                | +---------------+ |
```
[Section 1.1](https://tools.ietf.org/html/rfc7636#section-1.1)

The `code_challenge_method` may be `plain` or `S256`. For `S256` the `code_challenge` is
`BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))` using the raw digest and no padding
([Section 4.2](https://tools.ietf.org/html/rfc7636#section-4.2)). Authorization requests with another
method, or with a method but no `code_challenge`, are rejected with `invalid_request`.

{% include oauth-tokens-pkce.html %}
