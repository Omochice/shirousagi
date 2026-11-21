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
impl ServerInfoPort for FakeServerInfo with fn wiki_rpc_version(self) {
  self.calls.push("wiki_rpc_version")
  2
}

///|
impl ServerInfoPort for FakeServerInfo with fn trac_methods(self) {
  self.calls.push("methods")
  ["system.listMethods", "ticket.get"]
}

///|
impl ServerInfoPort for FakeServerInfo with fn trac_method_help(self, name) {
  self.calls.push("help \{name}")
  "array ticket.get(int id)"
}

///|
impl ServerInfoPort for FakeServerInfo with fn trac_method_signature(self, name) {
  self.calls.push("signature \{name}")
  ["array,int"]
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

///|
async test "the introspection actions reach their port methods and answer their JSON" {
  let fake = FakeServerInfo::new()
  let tools = [server_info_tool(fake)]
  let requests : Array[(Json, String)] = [
    ({ "wiki_rpc_version": {} }, "{\"wiki_rpc_version\":2}"),
    ({ "methods": {} }, "[\"system.listMethods\",\"ticket.get\"]"),
    (
      { "method_help": { "name": "ticket.get" } },
      "\"array ticket.get(int id)\"",
    ),
    ({ "method_signature": { "name": "ticket.get" } }, "[\"array,int\"]"),
  ]
  for entry in requests {
    assert_eq(call_tool(tools, "shirousagi_info", entry.0).text, entry.1)
  }
  assert_eq(fake.calls, [
    "wiki_rpc_version", "methods", "help ticket.get", "signature ticket.get",
  ])
}

///|
async test "method_help and method_signature need a method name" {
  let fake = FakeServerInfo::new()
  let tools = [server_info_tool(fake)]
  for action in ["method_help", "method_signature"] {
    let called = call_tool(
      tools,
      "shirousagi_info",
      Json::object(Map([(action, { "name": "" })])),
    )
    assert_true(
      called.text.contains(
        "invalid arguments: \{action}.name: must not be blank",
      ),
      msg=called.text,
    )
  }
  assert_eq(fake.calls, [])
}
