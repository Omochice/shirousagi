///|
struct FakeServerInfo {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeServerInfo::new(failure? : @trac.TracError) -> FakeServerInfo {
  { calls: [], failure, }
}

///|
impl ServerInfoPort for FakeServerInfo with fn trac_api_version(self) {
  self.calls.push("api_version")
  if self.failure is Some(error) {
    raise error
  }
  [1, 2, 0]
}

///|
async test "show reports the version and a null build from source without contacting Trac" {
  let fake = FakeServerInfo::new(failure=Transport(message="unreachable"))
  let called = call_tool(
    [server_info_tool(fake, build=None)],
    "shirousagi_info",
    { "show": {} },
  )
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"version\":\"\{@build.version}\",\"build\":null}")
  assert_eq(fake.calls, [])
}

///|
async test "show reports the build when one is embedded" {
  let build = Some(@build.BuildInfo::{ commit: "abc123", dirty: true, })
  let called = call_tool(
    [server_info_tool(FakeServerInfo::new(), build~)],
    "shirousagi_info",
    { "show": {} },
  )
  assert_eq(
    called.text,
    "{\"version\":\"\{@build.version}\",\"build\":{\"commit\":\"abc123\",\"dirty\":true}}",
  )
}

///|
async test "ping reports the Trac API version" {
  let fake = FakeServerInfo::new()
  let called = call_tool([server_info_tool(fake)], "shirousagi_info", {
    "ping": {},
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"api_version\":[1,2,0]}")
  assert_eq(fake.calls, ["api_version"])
}

///|
async test "ping turns a rejected login into a failure payload" {
  let called = call_tool(
    [server_info_tool(FakeServerInfo::new(failure=Http(status=401)))],
    "shirousagi_info",
    { "ping": {} },
  )
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":401,\"errors\":[\"HTTP 401: the username or password was rejected\"]}",
  )
}

///|
test "the checked-in build info is empty" {
  assert_true(@build.build is None)
}
