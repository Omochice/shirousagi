///|
async test "a wiki page goes through put, get, info, versions, recent changes and delete" {
  let trac = @livetest.admin()
  let name = @livetest.unique("Shirousagi/Page")
  let before = "2000-01-01T00:00:00Z"
  trac |> @wiki.put(name, "= First\n", comment="create")
  defer @livetest.cleanup(() => trac |> @wiki.delete(name))
  trac |> @wiki.put(name, "= Second\n", comment="edit")
  inspect(trac |> @wiki.get(name), content="= Second\n")
  inspect(trac |> @wiki.get(name, version=1), content="= First\n")
  let got = trac |> @wiki.info(name)
  guard got
    is {
      "version": Number(2, ..),
      "comment": "edit",
      "lastModified": String(modified),
      ..
    } else {
    fail("the page info lost its fields")
  }
  assert_true(modified.has_suffix("Z"), msg=modified)
  assert_true((trac |> @wiki.names()).contains(name))
  let got = trac |> @wiki.recent_changes(before)
  guard got is Array(changes) else { fail("recent changes is not an array") }
  assert_true(
    changes.any(page => page is { "name": String(n), .. } && n == name),
  )
  trac |> @wiki.delete(name, version=2)
  inspect(trac |> @wiki.get(name), content="= First\n")
  trac |> @wiki.delete(name)
  try trac |> @wiki.get(name) catch {
    Fault(code~, ..) => assert_eq(code, 404)
    error => fail("expected Fault 404, got \{error}")
  } noraise {
    _ => fail("the deleted page is still there")
  }
}

///|
async test "the viewer may read but not write the wiki" {
  let viewer = @livetest.viewer()
  ignore(viewer |> @wiki.get("WikiStart"))
  let name = @livetest.unique("Refused")
  try viewer |> @wiki.put(name, "x") catch {
    Fault(code~, ..) => assert_eq(code, 403)
    error => fail("expected Fault 403, got \{error}")
  } noraise {
    _ => fail("the viewer wrote a page")
  }
}
