---
layout: post
title:  "OAuth 2.0 - Dynamic Client Registration"
date:   2018-10-28 14:00:00 -0700
permalink: /oauth/client-registration.html
categories: oauth
---

The Dynamic Client Registration endpoint adheres to [RFC-7591](https://tools.ietf.org/html/rfc7591).

```text
        +--------(A)- Initial Access Token (OPTIONAL)
        |
        |   +----(B)- Software Statement (OPTIONAL)
        |   |
        v   v
    +-----------+                                      +---------------+
    |           |--(C)- Client Registration Request -->|    Client     |
    | Client or |                                      | Registration  |
    | Developer |<-(D)- Client Information Response ---|   Endpoint    |
    |           |        or Client Error Response      +---------------+
    +-----------+
```
[Section 1.3](https://tools.ietf.org/html/rfc7591#section-1.3)

{% include oauth-dynamic-client-registration.html %}
