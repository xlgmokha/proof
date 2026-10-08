---
layout: post
title:  "OAuth 2.0 - Dynamic Client Management"
date:   2018-10-28 14:00:00 -0700
permalink: /oauth/client-management.html
categories: oauth
---
The Dynamic Client Management is described in [RFC-7592](https://tools.ietf.org/html/rfc7592)

```text
        +--------(A)- Initial Access Token (OPTIONAL)
        |
        |   +----(B)- Software Statement (OPTIONAL)
        |   |
        v   v
    +-----------+                                      +---------------+
    |           |--(C)- Client Registration Request -->|    Client     |
    |           |                                      | Registration  |
    |           |<-(D)- Client Information Response ---|   Endpoint    |
    |           |                                      +---------------+
    |           |
    |           |                                      +---------------+
    | Client or |--(E)- Read or Update Request ------->|               |
    | Developer |                                      |               |
    |           |<-(F)- Client Information Response ---|    Client     |
    |           |                                      | Configuration |
    |           |                                      |   Endpoint    |
    |           |                                      |               |
    |           |--(G)- Delete Request --------------->|               |
    |           |                                      |               |
    |           |<-(H)- Delete Confirmation -----------|               |
    +-----------+                                      +---------------+
```
[Section 1.3](https://tools.ietf.org/html/rfc7592#section-1.3)

The registration response contains the `registration_client_uri` and a `registration_access_token`.
Present the token as a bearer token to read (`GET`), replace (`PUT`) or delete (`DELETE`) the client.

Valid values replace the existing metadata and omitted fields are cleared. A client can only manage
itself. Deleting a client also revokes every token issued to it and responds with `204 No Content`.

{% include oauth-dynamic-client-delete.html %}
