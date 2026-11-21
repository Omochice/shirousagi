///|
/// Puts, reads back, renames on a second put, lists and deletes through `trac_attachments` for the owner `owner`.
async fn round_trip(server : @mcp.Server, owner : Map[String, Json]) -> Unit {
  fn args(fields : Map[String, Json]) -> Json {
    let all = owner.copy()
    for key, value in fields {
      all[key] = value
    }
    Json::object(all)
  }

  let put = args({ "filename": "a.bin", "content_base64": "/w==" })
  guard succeed(server, "trac_attachments", { "put": put })
    is { "filename": "a.bin", .. } else {
    fail("the first put was not stored as a.bin")
  }
  guard succeed(server, "trac_attachments", { "put": put })
    is { "filename": "a.2.bin", .. } else {
    fail("the second put without replace was not renamed to a.2.bin")
  }
  guard succeed(server, "trac_attachments", {
      "get": args({ "filename": "a.bin" }),
    })
    is { "filename": "a.bin", "content_base64": "/w==", .. } else {
    fail("the byte 0xff did not come back unchanged")
  }
  guard succeed(server, "trac_attachments", { "list": args({}) }) is Array(rows) else {
    fail("list did not answer an array")
  }
  for filename in ["a.bin", "a.2.bin"] {
    assert_true(
      rows.any(row => row is { "filename": String(f), .. } && f == filename),
      msg="\{filename} is not listed",
    )
  }
  ignore(
    succeed(server, "trac_attachments", {
      "delete": args({ "filename": "a.2.bin" }),
    }),
  )
  let gone = call(server, "trac_attachments", {
    "get": args({ "filename": "a.2.bin" }),
  })
  guard gone is { is_error: true, payload: { "status": Number(404, ..), .. }, } else {
    fail("the deleted attachment still answered \{gone.payload.stringify()}")
  }
}

///|
async test "trac_attachments round-trips a non-UTF-8 byte on a ticket" {
  let server = full()
  guard succeed(server, "trac_tickets", {
      "create": {
        "summary": Json(@livetest.unique("attachment ticket ")),
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
  round_trip(server, { "ticket": Json(id) })
}

///|
async test "trac_attachments round-trips a non-UTF-8 byte on a wiki page" {
  let server = full()
  let name = @livetest.unique("Shirousagi/McpAttached")
  ignore(
    succeed(server, "trac_wiki", {
      "put": { "name": Json(name), "text": "attached\n" },
    }),
  )
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_wiki", { "delete": { "name": Json(name) } }))
  })
  round_trip(server, { "page": Json(name) })
}

///|
async test "trac_attachments refuses malformed base64 before reaching Trac" {
  let called = call(full(), "trac_attachments", {
    "put": { "ticket": 1, "filename": "x", "content_base64": "%%%" },
  })
  assert_true(called.is_error)
  assert_true(
    called.payload.stringify().contains("must be base64 text"),
    msg=called.payload.stringify(),
  )
}
