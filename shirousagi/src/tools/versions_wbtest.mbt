///|
struct FakeVersions {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeVersions::new(failure? : @trac.TracError) -> FakeVersions {
  { calls: [], failure, }
}

///|
fn FakeVersions::record(
  self : FakeVersions,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn version_changes_label(changes : @versions.Changes) -> String {
  let name = changes.name.unwrap_or("-")
  let time = match changes.time {
    Some(At(iso)) => iso
    Some(Unset) => "unset"
    None => "-"
  }
  let description = changes.description.unwrap_or("-")
  "name=\{name} time=\{time} description=\{description}"
}

///|
impl VersionPort for FakeVersions with fn version_names(self) {
  self.record("names")
  ["1.0", "2.0"]
}

///|
impl VersionPort for FakeVersions with fn get_version(self, name) {
  self.record("get \{name}")
  { "name": Json(name), "time": Json::null(), "description": "" }
}

///|
impl VersionPort for FakeVersions with fn create_version(self, name, changes) {
  self.record("create \{name} \{version_changes_label(changes)}")
}

///|
impl VersionPort for FakeVersions with fn update_version(self, name, changes) {
  self.record("update \{name} \{version_changes_label(changes)}")
}

///|
impl VersionPort for FakeVersions with fn delete_version(self, name) {
  self.record("delete \{name}")
}

///|
fn versions_tools(fake : FakeVersions, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [versions_tool(fake, mode)]
}

///|
async test "versions: every action reaches its port method, and null clears the time" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
  let listed = call_tool(tools, "trac_versions", { "list": {} })
  assert_eq(listed.text, "[\"1.0\",\"2.0\"]")
  let got = call_tool(tools, "trac_versions", { "get": { "name": "1.0" } })
  assert_eq(got.text, "{\"name\":\"1.0\",\"time\":null,\"description\":\"\"}")
  let requests : Array[Json] = [
    {
      "create": {
        "name": "3.0",
        "time": "2030-01-31T09:00:00+09:00",
        "description": "Next",
      },
    },
    { "create": { "name": "4.0" } },
    { "update": { "name": "3.0", "new_name": "3.1", "time": Json::null() } },
    { "update": { "name": "3.1", "time": "2030-02-01T00:00:00Z" } },
    { "delete": { "name": "3.1" } },
  ]
  for arguments in requests {
    assert_eq(
      call_tool(tools, "trac_versions", arguments).text,
      "{\"ok\":true}",
    )
  }
  assert_eq(fake.calls, [
    "names", "get 1.0", "create 3.0 name=- time=2030-01-31T09:00:00+09:00 description=Next",
    "create 4.0 name=- time=- description=-", "update 3.0 name=3.1 time=unset description=-",
    "update 3.1 name=- time=2030-02-01T00:00:00Z description=-", "delete 3.1",
  ])
}

///|
async test "versions: validation reports the exact message for each rule" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake)
  let cases : Array[(Json, String)] = [
    (
      { "create": { "name": "3.0", "time": Json::null() } },
      "invalid arguments: create.time: expected a string",
    ),
    (
      { "update": { "name": "3.0", "time": "soon" } },
      "invalid arguments: update.time: must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
    ),
    (
      { "update": { "name": "3.0", "new_name": " " } },
      "invalid arguments: update.new_name: must not be blank",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_versions", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "versions: readonly mode keeps list and get only" {
  let fake = FakeVersions::new()
  let tools = versions_tools(fake, mode=Readonly)
  for action in ["create", "update", "delete"] {
    let called = call_tool(
      tools,
      "trac_versions",
      Json::object(Map([(action, { "name": "1.0" })])),
    )
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `\{action}`, one of `list` and `get`\"]}",
    )
  }
  assert_eq(fake.calls, [])
  guard list_tools(tools)
    is {
      "tools": [
        {
          "description": String(text),
          "inputSchema": { "properties": Object(actions), .. },
          ..
        },
      ],
      ..
    } else {
    fail("no keyed schema")
  }
  assert_eq(actions.keys().collect(), ["list", "get"])
  assert_true(text.has_prefix("List and show Trac ticket versions."))
  assert_false(text.contains("`update`"))
}

///|
async test "versions: a Trac failure becomes a failure payload" {
  let tools = versions_tools(
    FakeVersions::new(
      failure=Fault(code=404, message="Version 9 does not exist."),
    ),
  )
  let called = call_tool(tools, "trac_versions", { "get": { "name": "9" } })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":404,\"errors\":[\"Version 9 does not exist.\"]}",
  )
}
