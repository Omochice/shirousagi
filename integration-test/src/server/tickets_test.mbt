///|
async test "trac_tickets creates, reads, updates with the change token, logs and deletes a ticket" {
  let server = full()
  let summary = @livetest.unique("server ticket ")
  guard succeed(server, "trac_tickets", {
      "create": {
        "summary": Json(summary),
        "description": "made through MCP",
        "fields": { "type": "task", "keywords": "mcp-e2e" },
      },
    })
    is { "id": Number(id, ..), .. } else {
    fail("create did not answer an id")
  }
  let id = id.to_int()
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_tickets", { "delete": { "id": Json(id) } }))
  })
  guard succeed(server, "trac_tickets", { "get": { "id": Json(id) } })
    is { "summary": String(got), "type": "task", "_ts": String(ts), .. } else {
    fail("get lost the fields")
  }
  assert_eq(got, summary)
  guard succeed(server, "trac_tickets", {
      "query": { "query": "keywords~=mcp-e2e&max=0" },
    })
    is Array(ids) else {
    fail("query did not answer an array")
  }
  assert_true(ids.contains(Json(id)))
  guard succeed(server, "trac_tickets", {
      "update": {
        "id": Json(id),
        "comment": "changed through MCP",
        "fields": { "priority": "minor" },
        "ts": Json(ts),
      },
    })
    is { "priority": "minor", .. } else {
    fail("update did not answer the changed ticket")
  }
  let stale = call(server, "trac_tickets", {
    "update": { "id": Json(id), "comment": "stale", "ts": Json(ts) },
  })
  assert_true(stale.is_error, msg="a stale update was saved")
  guard succeed(server, "trac_tickets", { "changelog": { "id": Json(id) } })
    is Array(changes) else {
    fail("changelog did not answer an array")
  }
  assert_true(
    changes.any(change => {
      change is { "field": "comment", "newvalue": "changed through MCP", .. }
    }),
  )
}

///|
async test "trac_tickets resolves a ticket with the input its action lists" {
  let server = full()
  guard succeed(server, "trac_tickets", {
      "create": {
        "summary": Json(@livetest.unique("resolve ")),
        "description": "",
      },
    })
    is { "id": Number(id, ..), .. } else {
    fail("create did not answer an id")
  }
  let id = id.to_int()
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_tickets", { "delete": { "id": Json(id) } }))
  })
  guard succeed(server, "trac_tickets", { "actions": { "id": Json(id) } })
    is Array(actions) else {
    fail("actions did not answer an array")
  }
  guard actions.search_by(action => action is { "name": "resolve", .. })
    is Some(index) else {
    fail("no resolve action")
  }
  guard actions[index] is { "inputs": [{ "name": String(input), .. }], .. } else {
    fail("resolve lists no input")
  }
  let fields : Map[String, Json] = Map([(input, Json("wontfix"))])
  guard succeed(server, "trac_tickets", {
      "update": {
        "id": Json(id),
        "action": "resolve",
        "fields": Json::object(fields),
      },
    })
    is { "status": "closed", "resolution": "wontfix", .. } else {
    fail("resolving did not close the ticket")
  }
}

///|
async test "a missing ticket is an error payload with Trac's 404" {
  let called = call(full(), "trac_tickets", { "get": { "id": 999999 } })
  assert_true(called.is_error)
  guard called.payload
    is { "status": Number(404, ..), "errors": [String(_)], .. } else {
    fail("unexpected failure payload \{called.payload.stringify()}")
  }
}

///|
async test "the viewer's create is an error payload with Trac's 403" {
  let server = @cli.build_server(@livetest.viewer(), false)
  let called = call(server, "trac_tickets", {
    "create": {
      "summary": Json(@livetest.unique("refused ")),
      "description": "",
    },
  })
  assert_true(called.is_error)
  guard called.payload is { "status": Number(403, ..), .. } else {
    fail("unexpected failure payload \{called.payload.stringify()}")
  }
}
