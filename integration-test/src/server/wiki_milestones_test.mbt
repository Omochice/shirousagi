///|
async test "trac_wiki puts, reads, lists, reports recent changes and deletes a page" {
  let server = full()
  let name = @livetest.unique("Shirousagi/Mcp")
  ignore(
    succeed(server, "trac_wiki", {
      "put": { "name": Json(name), "text": "= Via MCP\n", "comment": "first" },
    }),
  )
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_wiki", { "delete": { "name": Json(name) } }))
  })
  inspect(
    succeed(server, "trac_wiki", { "get": { "name": Json(name) } }).stringify(),
    content="\"= Via MCP\\n\"",
  )
  guard succeed(server, "trac_wiki", { "info": { "name": Json(name) } })
    is { "version": Number(1, ..), "comment": "first", .. } else {
    fail("info lost the fields")
  }
  guard succeed(server, "trac_wiki", { "list": {} }) is Array(names) else {
    fail("list did not answer an array")
  }
  assert_true(names.contains(Json(name)))
  // An offset other than UTC proves the server passes it through rather than reading the time as UTC.
  guard succeed(server, "trac_wiki", {
      "recent_changes": { "since": "2000-01-01T09:00:00+09:00" },
    })
    is Array(changes) else {
    fail("recent_changes did not answer an array")
  }
  assert_true(
    changes.any(page => page is { "name": String(n), .. } && n == name),
  )
}

///|
async test "trac_milestones creates with an offset, clears a date with null, and deletes" {
  let server = full()
  let name = @livetest.unique("server milestone ")
  ignore(
    succeed(server, "trac_milestones", {
      "create": {
        "name": Json(name),
        "due": "2030-01-31T09:00:00+09:00",
        "description": "made through MCP",
      },
    }),
  )
  defer @livetest.cleanup(() => {
    ignore(
      succeed(server, "trac_milestones", { "delete": { "name": Json(name) } }),
    )
  })
  guard succeed(server, "trac_milestones", { "get": { "name": Json(name) } })
    is { "due": "2030-01-31T00:00:00Z", .. } else {
    fail("the due date was not stored as the same instant in UTC")
  }
  ignore(
    succeed(server, "trac_milestones", {
      "update": { "name": Json(name), "due": Json::null() },
    }),
  )
  guard succeed(server, "trac_milestones", { "get": { "name": Json(name) } })
    is { "due": Null, .. } else {
    fail("null did not clear the due date")
  }
  guard succeed(server, "trac_milestones", { "list": {} }) is Array(names) else {
    fail("list did not answer an array")
  }
  assert_true(names.contains(Json(name)))
}

///|
async test "trac_search finds a ticket and shirousagi_info pings Trac" {
  let server = full()
  let word = @livetest.unique("haystack")
  guard succeed(server, "trac_tickets", {
      "create": { "summary": Json("find \{word}"), "description": "" },
    })
    is { "id": Number(id, ..), .. } else {
    fail("create did not answer an id")
  }
  let id = id.to_int()
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_tickets", { "delete": { "id": Json(id) } }))
  })
  guard succeed(server, "trac_search", {
      "search": { "query": Json(word), "filters": ["ticket"] },
    })
    is Array(results) else {
    fail("search did not answer an array")
  }
  assert_true(
    results.any(result => {
      result is { "href": String(href), .. } && href.has_suffix("/ticket/\{id}")
    }),
  )
  guard succeed(server, "shirousagi_info", { "ping": {} })
    is { "api_version": Array(_), .. } else {
    fail("ping did not answer the API version")
  }
}

///|
async test "a rejected login is an error payload with status 401" {
  let trac = @trac.new(
    endpoint=@livetest.endpoint(),
    username="admin",
    password="not-the-password",
  )
  let called = call(@cli.build_server(trac, true), "shirousagi_info", {
    "ping": {},
  })
  assert_true(called.is_error)
  guard called.payload is { "status": Number(401, ..), .. } else {
    fail("unexpected failure payload \{called.payload.stringify()}")
  }
}

///|
async test "the readonly server refuses a write as an unknown action" {
  let called = call(@cli.build_server(@livetest.admin(), true), "trac_wiki", {
    "put": { "name": "Refused", "text": "x" },
  })
  assert_true(called.is_error)
  assert_true(
    called.payload.stringify().contains("invalid arguments"),
    msg=called.payload.stringify(),
  )
}

///|
async test "trac_wiki renders a page and markup as HTML" {
  let server = full()
  let name = @livetest.unique("Shirousagi/Rendered")
  ignore(
    succeed(server, "trac_wiki", {
      "put": {
        "name": Json(name),
        "text": "= Rendered\nSee [wiki:WikiStart].\n",
      },
    }),
  )
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_wiki", { "delete": { "name": Json(name) } }))
  })
  for version in [Json::null(), Json(1)] {
    let arguments : Map[String, Json] = { "name": Json(name) }
    if version is Number(_, ..) {
      arguments["version"] = version
    }
    guard succeed(server, "trac_wiki", { "html": Json::object(arguments) })
      is String(html) else {
      fail("html did not answer text")
    }
    assert_true(html.contains("Rendered</h1>"), msg=html)
    assert_true(html.contains("/wiki/WikiStart"), msg=html)
  }
  guard succeed(server, "trac_wiki", { "render": { "text": "= hi" } })
    is String(fragment) else {
    fail("render did not answer text")
  }
  assert_true(
    fragment.contains("<h1") && fragment.contains("hi</h1>"),
    msg=fragment,
  )
}
