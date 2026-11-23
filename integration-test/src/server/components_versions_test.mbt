///|
async test "trac_components creates, reads, renames and deletes a component" {
  let server = full()
  let name = @livetest.unique("server component ")
  let renamed = "\{name} renamed"
  ignore(
    succeed(server, "trac_components", {
      "create": { "name": Json(name), "owner": "admin", "description": "made" },
    }),
  )
  defer @livetest.cleanup(() => {
    for leftover in [name, renamed] {
      ignore(
        call(server, "trac_components", { "delete": { "name": Json(leftover) } }),
      )
    }
  })
  guard succeed(server, "trac_components", { "get": { "name": Json(name) } })
    is { "owner": "admin", "description": "made", .. } else {
    fail("get lost the owner or the description")
  }
  ignore(
    succeed(server, "trac_components", {
      "update": { "name": Json(name), "new_name": Json(renamed), "owner": "" },
    }),
  )
  guard succeed(server, "trac_components", { "get": { "name": Json(renamed) } })
    is { "owner": "", "description": "made", .. } else {
    fail("update did not keep the description it was not given")
  }
  guard succeed(server, "trac_components", { "list": {} }) is Array(names) else {
    fail("list did not answer an array")
  }
  assert_true(names.contains(Json(renamed)))
  assert_false(names.contains(Json(name)))
  ignore(
    succeed(server, "trac_components", { "delete": { "name": Json(renamed) } }),
  )
  let gone = call(server, "trac_components", {
    "get": { "name": Json(renamed) },
  })
  guard gone is { is_error: true, payload: { "status": Number(404, ..), .. }, } else {
    fail("the deleted component answered \{gone.payload.stringify()}")
  }
}

///|
async test "trac_versions stores a time with an offset, clears it with null, and deletes" {
  let server = full()
  let name = @livetest.unique("server version ")
  ignore(
    succeed(server, "trac_versions", {
      "create": { "name": Json(name), "time": "2030-01-31T09:00:00+09:00" },
    }),
  )
  defer @livetest.cleanup(() => {
    ignore(
      succeed(server, "trac_versions", { "delete": { "name": Json(name) } }),
    )
  })
  guard succeed(server, "trac_versions", { "get": { "name": Json(name) } })
    is { "time": "2030-01-31T00:00:00Z", .. } else {
    fail("the time was not stored as the same instant in UTC")
  }
  ignore(
    succeed(server, "trac_versions", {
      "update": { "name": Json(name), "time": Json::null(), "description": "d" },
    }),
  )
  guard succeed(server, "trac_versions", { "get": { "name": Json(name) } })
    is { "time": Null, "description": "d", .. } else {
    fail("null did not clear the time")
  }
  guard succeed(server, "trac_versions", { "list": {} }) is Array(names) else {
    fail("list did not answer an array")
  }
  assert_true(names.contains(Json(name)))
}

///|
async test "the viewer's component create is an error payload with Trac's 403" {
  let server = @cli.build_server(@livetest.viewer(), false)
  let called = call(server, "trac_components", {
    "create": { "name": Json(@livetest.unique("refused component ")) },
  })
  assert_true(called.is_error)
  guard called.payload is { "status": Number(403, ..), .. } else {
    fail("unexpected failure payload \{called.payload.stringify()}")
  }
}
