///|
async test "the administrator logs in and reads the API version" {
  let version = @livetest.admin() |> @trac.api_version()
  guard version is Array([Number(_, ..), Number(major, ..), Number(_, ..)]) else {
    fail("unexpected API version \{version.stringify()}")
  }
  assert_true(major >= 1)
}

///|
async test "a wrong password is rejected with HTTP 401" {
  let trac = @trac.new(
    endpoint=@livetest.endpoint(),
    username="admin",
    password="not-the-password",
  )
  try trac |> @trac.api_version() catch {
    Http(status~) => assert_eq(status, 401)
    error => fail("expected Http(401), got \{error}")
  } noraise {
    _ => fail("a wrong password was accepted")
  }
}

///|
async test "an unknown method is a fault naming it" {
  let trac = @livetest.admin()
  try trac |> @trac.call("no.such", []) catch {
    Fault(code~, message~) => {
      assert_eq(code, -32601)
      assert_true(message.contains("no.such"), msg=message)
    }
    error => fail("expected Fault, got \{error}")
  } noraise {
    _ => fail("an unknown method answered")
  }
}

///|
async test "a project URL without TracXMLRPC behind it is a decode failure" {
  let trac = @trac.new(
    endpoint="\{@livetest.endpoint()}/no-such-project",
    username="admin",
    password="unused",
  )
  try trac |> @trac.api_version() catch {
    Http(..) | Decode(..) => ()
    error => fail("expected Http or Decode, got \{error}")
  } noraise {
    _ => fail("a missing RPC handler answered")
  }
}

///|
async test "a multicall answers each call's result or fault in order" {
  let outcomes = @livetest.admin()
    |> @trac.multicall([
      ("ticket.priority.getAll", []),
      ("ticket.get", [99999]),
      ("system.getAPIVersion", []),
    ])
  guard outcomes
    is [
      Ok(Array(priorities)),
      Err(Fault(code=404, message~)),
      Ok(Array([_, _, _])),
    ] else {
    fail("the outcomes were not answered per call")
  }
  assert_true(priorities.contains(Json("major")))
  assert_true(message.contains("99999"), msg=message)
}
