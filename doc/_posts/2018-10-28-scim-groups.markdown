---
layout: post
title:  "SCIM - Groups"
date:   2018-10-28 17:00:00 -0600
permalink: /scim/groups.html
categories: scim
---

This endpoint adheres to [RFC-7644](https://tools.ietf.org/html/rfc7644#section-3).

Groups are available at `/scim/v2/Groups` and support `GET` (list and read), `POST`, `PUT`, `PATCH`
and `DELETE`. Lists support `filter` (for example `displayName eq "Engineering"`), `startIndex` and
`count`. Members are users, referenced by their `value`. A group's `displayName` must be unique
ignoring case. Users report their groups in the read-only `groups` attribute.

Creating a group fails with `409` and a `scimType` of `uniqueness` when the name is taken, and with
`400` and a `scimType` of `invalidValue` when a member does not exist.

{% include scim-groups-create.html %}

See [PATCH](/doc/scim/patch.html) for modifying a group.
