///|
struct FakeEnums {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeEnums::new(failure? : @trac.TracError) -> FakeEnums {
  { calls: [], failure, }
}

///|
fn FakeEnums::record(
  self : FakeEnums,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn kind_label(kind : @enums.Kind) -> String {
  match kind {
    Type => "type"
    Resolution => "resolution"
    Priority => "priority"
    Severity => "severity"
  }
}

///|
impl EnumPort for FakeEnums with fn enum_names(self, kind) {
  self.record("names \{kind_label(kind)}")
  ["blocker", "major"]
}

///|
impl EnumPort for FakeEnums with fn get_enum(self, kind, name) {
  self.record("get \{kind_label(kind)} \{name}")
  "3"
}

///|
impl EnumPort for FakeEnums with fn ticket_statuses(self) {
  self.record("statuses")
  ["closed", "new"]
}

///|
impl EnumPort for FakeEnums with fn create_enum(self, kind, name, value~) {
  self.record("create \{kind_label(kind)} \{name} \{value}")
}

///|
impl EnumPort for FakeEnums with fn update_enum(self, kind, name, value~) {
  self.record("update \{kind_label(kind)} \{name} \{value}")
}

///|
impl EnumPort for FakeEnums with fn delete_enum(self, kind, name) {
  self.record("delete \{kind_label(kind)} \{name}")
}

///|
fn enums_tools(fake : FakeEnums, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [enums_tool(fake, mode)]
}

///|
async test "enums: every action reaches its port method with its kind" {
  let fake = FakeEnums::new()
  let tools = enums_tools(fake)
  let listed = call_tool(tools, "trac_enums", { "list": { "kind": "priority" } })
  assert_eq(listed.text, "[\"blocker\",\"major\"]")
  let got = call_tool(tools, "trac_enums", {
    "get": { "kind": "severity", "name": "major" },
  })
  assert_eq(got.text, "{\"name\":\"major\",\"value\":\"3\"}")
  let statuses = call_tool(tools, "trac_enums", { "statuses": {} })
  assert_eq(statuses.text, "[\"closed\",\"new\"]")
  let requests : Array[Json] = [
    { "create": { "kind": "type", "name": "chore", "value": "4" } },
    { "update": { "kind": "resolution", "name": "fixed", "value": "2" } },
    { "delete": { "kind": "type", "name": "chore" } },
  ]
  for arguments in requests {
    assert_eq(call_tool(tools, "trac_enums", arguments).text, "{\"ok\":true}")
  }
  assert_eq(fake.calls, [
    "names priority", "get severity major", "statuses", "create type chore 4", "update resolution fixed 2",
    "delete type chore",
  ])
}

///|
async test "enums: validation reports the exact message for each rule" {
  let fake = FakeEnums::new()
  let tools = enums_tools(fake)
  let cases : Array[(Json, String)] = [
    ({ "list": {} }, "invalid arguments: list.kind: is required"),
    (
      { "list": { "kind": "status" } },
      "invalid arguments: list.kind: must be one of `type`, `resolution`, `priority` and `severity`",
    ),
    (
      { "create": { "kind": "type", "name": "chore" } },
      "invalid arguments: create.value: is required",
    ),
    (
      { "statuses": { "kind": "type" } },
      "invalid arguments: statuses.kind: unknown field",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_enums", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "enums: readonly mode keeps list, get and statuses" {
  let fake = FakeEnums::new()
  let tools = enums_tools(fake, mode=Readonly)
  for action in ["create", "update", "delete"] {
    let called = call_tool(
      tools,
      "trac_enums",
      Json::object(
        Map([(action, { "kind": "type", "name": "chore", "value": "4" })]),
      ),
    )
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `\{action}`, one of `list`, `get` and `statuses`\"]}",
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
  assert_eq(actions.keys().collect(), ["list", "get", "statuses"])
  assert_true(text.has_prefix("List and show Trac ticket types"))
  assert_false(text.contains("`update`"))
}

///|
async test "enums: a Trac failure becomes a failure payload" {
  let tools = enums_tools(
    FakeEnums::new(
      failure=Fault(code=404, message="Severity nope does not exist."),
    ),
  )
  let called = call_tool(tools, "trac_enums", {
    "get": { "kind": "severity", "name": "nope" },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":404,\"errors\":[\"Severity nope does not exist.\"]}",
  )
}
