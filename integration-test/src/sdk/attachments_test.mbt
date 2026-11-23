///|
async test "a ticket attachment keeps bytes that are not UTF-8 and is renamed rather than overwritten" {
  let trac = @livetest.admin()
  let id = trac
    |> @tickets.create(
      summary=@livetest.unique("attachment ticket "),
      description="",
    )
  defer @livetest.cleanup(() => trac |> @tickets.delete(id))
  let target : @attachments.Target = Ticket(id)
  let content = b"\xff\x00\xfe"
  inspect(
    trac |> @attachments.put(target, "a.bin", content, description="raw"),
    content="a.bin",
  )
  assert_eq(trac |> @attachments.get(target, "a.bin"), content)
  inspect(trac |> @attachments.put(target, "a.bin", b"\x01"), content="a.2.bin")
  let rows = trac |> @attachments.list(target)
  guard rows
    is [
      {
        "filename": "a.bin",
        "description": "raw",
        "size": Number(3, ..),
        "time": String(time),
        "author": String(_),
        ..
      },
      { "filename": "a.2.bin", .. },
    ] else {
    fail("list lost the attachments or their fields")
  }
  assert_true(time.has_suffix("Z"), msg=time)
  trac |> @attachments.delete(target, "a.2.bin")
  try trac |> @attachments.get(target, "a.2.bin") catch {
    Fault(code~, ..) => assert_eq(code, 404)
    error => fail("expected Fault 404, got \{error}")
  } noraise {
    _ => fail("the deleted attachment is still there")
  }
}

///|
async test "a wiki attachment on a nested page lists by its bare filename" {
  let trac = @livetest.admin()
  let page = @livetest.unique("Shirousagi/Attached")
  trac |> @wiki.put(page, "attached\n")
  defer @livetest.cleanup(() => trac |> @wiki.delete(page))
  let target : @attachments.Target = Wiki(page)
  inspect(trac |> @attachments.put(target, "p.bin", b"\xff"), content="p.bin")
  assert_eq(trac |> @attachments.get(target, "p.bin"), b"\xff")
  inspect(
    trac |> @attachments.put(target, "p.bin", b"\x00", replace=true),
    content="p.bin",
  )
  assert_eq(trac |> @attachments.get(target, "p.bin"), b"\x00")
  inspect(
    Json::array(trac |> @attachments.list(target)).stringify(),
    content=(
      #|[{"filename":"p.bin"}]
    ),
  )
  trac |> @attachments.delete(target, "p.bin")
  assert_eq(trac |> @attachments.list(target), [])
}
