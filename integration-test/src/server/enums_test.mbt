///|
async test "trac_enums creates, reads, updates and deletes a severity" {
  let server = full()
  let name = @livetest.unique("server severity ")
  ignore(
    succeed(server, "trac_enums", {
      "create": { "kind": "severity", "name": Json(name), "value": "1" },
    }),
  )
  defer @livetest.cleanup(() => {
    ignore(
      succeed(server, "trac_enums", {
        "delete": { "kind": "severity", "name": Json(name) },
      }),
    )
  })
  ignore(
    succeed(server, "trac_enums", {
      "update": { "kind": "severity", "name": Json(name), "value": "7" },
    }),
  )
  guard succeed(server, "trac_enums", {
      "get": { "kind": "severity", "name": Json(name) },
    })
    is { "value": "7", .. } else {
    fail("update did not set the value")
  }
  guard succeed(server, "trac_enums", { "list": { "kind": "severity" } })
    is Array(names) else {
    fail("list did not answer an array")
  }
  assert_true(names.contains(Json(name)))
}

///|
async test "trac_enums lists the seeded types and the workflow statuses" {
  let server = full()
  guard succeed(server, "trac_enums", { "list": { "kind": "type" } })
    is Array(types) else {
    fail("list did not answer an array")
  }
  assert_true(types.contains(Json("defect")))
  guard succeed(server, "trac_enums", { "statuses": {} }) is Array(statuses) else {
    fail("statuses did not answer an array")
  }
  assert_true(
    statuses.contains(Json("new")) && statuses.contains(Json("closed")),
  )
}
