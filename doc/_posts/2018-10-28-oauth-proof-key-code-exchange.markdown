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

{% include oauth-tokens-pkce.html %}
