///|
async test "a ticket goes through create, get, query, update, changelog and delete" {
  let trac = @livetest.admin()
  let summary = @livetest.unique("shirousagi ticket ")
  let id = trac
    |> @tickets.create(summary~, description="made by a test", fields={
      "type": "task",
      "keywords": "e2e",
    })
  defer @livetest.cleanup(() => trac |> @tickets.delete(id))
  let got = trac |> @tickets.get(id)
  guard got is { "summary": String(got), "type": "task", "_ts": String(ts), .. } else {
    fail("the created ticket lost its fields")
  }
  assert_eq(got, summary)
  assert_true(
    (trac |> @tickets.query("keywords~=e2e&max=0")).contains(id),
    msg="the query does not find the new ticket",
  )
  let updated = trac
    |> @tickets.update(
      id,
      comment="first change",
      fields={ "priority": "minor" },
      ts~,
    )
  guard updated is { "priority": "minor", .. } else {
    fail("update did not return the changed ticket: \{updated.stringify()}")
  }
  let changes = trac |> @tickets.changelog(id)
  assert_true(
    changes.any(change => {
      change is { "field": "comment", "newvalue": "first change", .. }
    }),
  )
  assert_true(
    changes.any(change => {
      change is { "field": "priority", "newvalue": "minor", .. }
    }),
  )
  trac |> @tickets.delete(id)
  try trac |> @tickets.get(id) catch {
    Fault(code~, ..) => assert_eq(code, 404)
    error => fail("expected Fault 404, got \{error}")
  } noraise {
    _ => fail("the deleted ticket is still there")
  }
}

///|
async test "an update with a stale change token is refused" {
  let trac = @livetest.admin()
  let id = trac
    |> @tickets.create(summary=@livetest.unique("stale "), description="")
  defer @livetest.cleanup(() => trac |> @tickets.delete(id))
  let got = trac |> @tickets.get(id)
  guard got is { "_ts": String(ts), .. } else { fail("no _ts") }
  ignore(trac |> @tickets.update(id, comment="moves the token", ts~))
  try trac |> @tickets.update(id, comment="based on the old token", ts~) catch {
    Fault(message~, ..) =>
      assert_true(message.contains("modified"), msg=message)
    error => fail("expected Fault, got \{error}")
  } noraise {
    _ => fail("a stale update was saved")
  }
}

///|
async test "an update without a change token reads the current one" {
  let trac = @livetest.admin()
  let id = trac
    |> @tickets.create(summary=@livetest.unique("no token "), description="")
  defer @livetest.cleanup(() => trac |> @tickets.delete(id))
  ignore(trac |> @tickets.update(id, comment="one"))
  let got = trac
    |> @tickets.update(id, comment="two", fields={ "keywords": "k" })
  guard got is { "keywords": "k", .. } else {
    fail("the second update was not applied")
  }
}

///|
async test "the workflow actions of a new ticket include resolve with its inputs" {
  let trac = @livetest.admin()
  let id = trac
    |> @tickets.create(summary=@livetest.unique("actions "), description="")
  defer @livetest.cleanup(() => trac |> @tickets.delete(id))
  let actions = trac |> @tickets.actions(id)
  guard actions.search_by(action => action is { "name": "resolve", .. })
    is Some(index) else {
    fail("no resolve action")
  }
  guard actions[index] is { "inputs": [{ "name": String(input), .. }], .. } else {
    fail("resolve has no input")
  }
  let got = trac
    |> @tickets.update(
      id,
      action="resolve",
      fields=Map([(input, Json("fixed"))]),
    )
  guard got is { "status": "closed", "resolution": "fixed", .. } else {
    fail("resolving did not close the ticket")
  }
}

///|
async test "the ticket fields list the select options" {
  let fields = @livetest.admin() |> @tickets.fields()
  guard fields is Array(fields) else { fail("fields is not an array") }
  assert_true(
    fields.any(field => field is { "name": "type", "options": Array(_), .. }),
  )
}

///|
async test "the viewer may not create a ticket" {
  let viewer = @livetest.viewer()
  let summary = @livetest.unique("refused ")
  try viewer |> @tickets.create(summary~, description="") catch {
    Fault(code~, ..) => assert_eq(code, 403)
    error => fail("expected Fault 403, got \{error}")
  } noraise {
    id => {
      @livetest.cleanup(() => @livetest.admin() |> @tickets.delete(id))
      fail("the viewer created ticket \{id}")
    }
  }
}
