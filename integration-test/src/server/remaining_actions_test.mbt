///|
async test "trac_wiki reads and deletes one version of a page" {
  let server = full()
  let name = @livetest.unique("Shirousagi/Versions")
  for text in ["= One\n", "= Two\n"] {
    ignore(
      succeed(server, "trac_wiki", {
        "put": { "name": Json(name), "text": Json(text) },
      }),
    )
  }
  defer @livetest.cleanup(() => {
    ignore(succeed(server, "trac_wiki", { "delete": { "name": Json(name) } }))
  })
  inspect(
    succeed(server, "trac_wiki", { "get": { "name": Json(name), "version": 1 } }).stringify(),
    content="\"= One\\n\"",
  )
  guard succeed(server, "trac_wiki", {
      "info": { "name": Json(name), "version": 1 },
    })
    is { "version": Number(1, ..), .. } else {
    fail("info of version 1 answered another version")
  }
  ignore(
    succeed(server, "trac_wiki", {
      "delete": { "name": Json(name), "version": 2 },
    }),
  )
  inspect(
    succeed(server, "trac_wiki", { "get": { "name": Json(name) } }).stringify(),
    content="\"= One\\n\"",
  )
}

///|
async test "trac_milestones sets completed and renames with new_name" {
  let server = full()
  let name = @livetest.unique("server rename ")
  let renamed = "\{name} renamed"
  ignore(
    succeed(server, "trac_milestones", { "create": { "name": Json(name) } }),
  )
  defer @livetest.cleanup(() => {
    ignore(
      call(server, "trac_milestones", { "delete": { "name": Json(name) } }),
    )
    ignore(
      call(server, "trac_milestones", { "delete": { "name": Json(renamed) } }),
    )
  })
  ignore(
    succeed(server, "trac_milestones", {
      "update": {
        "name": Json(name),
        "new_name": Json(renamed),
        "completed": "2030-03-01T00:00:00Z",
      },
    }),
  )
  guard succeed(server, "trac_milestones", { "get": { "name": Json(renamed) } })
    is { "completed": "2030-03-01T00:00:00Z", .. } else {
    fail("the renamed milestone lost its completion date")
  }
  assert_true(
    call(server, "trac_milestones", { "get": { "name": Json(name) } }).is_error,
  )
}

///|
async test "the field, filter and server descriptions answer" {
  let server = full()
  guard succeed(server, "trac_tickets", { "fields": {} }) is Array(fields) else {
    fail("fields did not answer an array")
  }
  assert_true(fields.any(field => field is { "name": "summary", .. }))
  guard succeed(server, "trac_search", { "filters": {} }) is Array(filters) else {
    fail("filters did not answer an array")
  }
  assert_true(filters.any(filter => filter is { "name": "wiki", .. }))
  guard succeed(server, "shirousagi_info", { "show": {} })
    is { "version": String(_), .. } else {
    fail("show did not answer the server version")
  }
}
