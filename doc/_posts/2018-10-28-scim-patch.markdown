---
layout: post
title:  "SCIM - PATCH"
date:   2018-10-28 17:00:00 -0600
permalink: /scim/patch.html
categories: scim
---

This endpoint adheres to [RFC-7644 Section 3.5.2](https://tools.ietf.org/html/rfc7644#section-3.5.2).

`PATCH /scim/v2/Users/:id` and `PATCH /scim/v2/Groups/:id` accept a `PatchOp` message of `add`,
`remove` and `replace` operations. Operations are applied in order and either all succeed or none are
applied. Without a `path` the `value` is an object of attributes.

| Resource | Attributes |
| -------- | ---------- |
| User | `userName`, `emails` (the first or primary value), `locale`, `timezone`, `password` |
| Group | `displayName`, `members` |

* `members` can be added to, replaced, or removed as a whole or with a filter such as
  `members[value eq "2819c223-7f76-453a-919d-413861904646"]`. Only `eq` filters are supported.
* A password can only be changed by the user it belongs to.
* `userName` and `displayName` are required and cannot be removed.

Failures are `400` with a `scimType` of `invalidSyntax`, `invalidPath`, `invalidValue`, `noTarget` or
`mutability`, or `409` with `uniqueness`.

#### Users

{% include scim-users-patch.html %}

#### Groups

{% include scim-groups-patch.html %}
