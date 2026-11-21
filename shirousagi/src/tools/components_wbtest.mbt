///|
struct FakeComponents {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeComponents::new(failure? : @trac.TracError) -> FakeComponents {
  { calls: [], failure, }
}

///|
fn FakeComponents::record(
  self : FakeComponents,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn component_changes_label(changes : @components.Changes) -> String {
  let name = changes.name.unwrap_or("-")
  let owner = changes.owner.unwrap_or("-")
  let description = changes.description.unwrap_or("-")
  "name=\{name} owner=\{owner} description=\{description}"
}

///|
impl ComponentPort for FakeComponents with fn component_names(self) {
  self.record("names")
  ["component1", "component2"]
}

///|
impl ComponentPort for FakeComponents with fn get_component(self, name) {
  self.record("get \{name}")
  { "name": Json(name), "owner": "alice", "description": "" }
}

///|
impl ComponentPort for FakeComponents with fn create_component(
  self,
  name,
  changes,
) {
  self.record("create \{name} \{component_changes_label(changes)}")
}

///|
impl ComponentPort for FakeComponents with fn update_component(
  self,
  name,
  changes,
) {
  self.record("update \{name} \{component_changes_label(changes)}")
}

///|
impl ComponentPort for FakeComponents with fn delete_component(self, name) {
  self.record("delete \{name}")
}

///|
fn components_tools(
  fake : FakeComponents,
  mode~ : Mode = Full,
) -> Array[@mcp.Tool] {
  [components_tool(fake, mode)]
}

///|
async test "components: every action reaches its port method" {
  let fake = FakeComponents::new()
  let tools = components_tools(fake)
  let listed = call_tool(tools, "trac_components", { "list": {} })
  assert_eq(listed.text, "[\"component1\",\"component2\"]")
  let got = call_tool(tools, "trac_components", { "get": { "name": "ui" } })
  assert_eq(
    got.text,
    "{\"name\":\"ui\",\"owner\":\"alice\",\"description\":\"\"}",
  )
  let requests : Array[Json] = [
    { "create": { "name": "ui", "owner": "alice", "description": "Front" } },
    { "create": { "name": "db" } },
    { "update": { "name": "ui", "new_name": "web", "owner": "" } },
    { "delete": { "name": "web" } },
  ]
  for arguments in requests {
    assert_eq(
      call_tool(tools, "trac_components", arguments).text,
      "{\"ok\":true}",
    )
  }
  assert_eq(fake.calls, [
    "names", "get ui", "create ui name=- owner=alice description=Front", "create db name=- owner=- description=-",
    "update ui name=web owner= description=-", "delete web",
  ])
}

///|
async test "components: validation reports the exact message for each rule" {
  let fake = FakeComponents::new()
  let tools = components_tools(fake)
  let cases : Array[(Json, String)] = [
    (
      { "get": { "name": "" } },
      "invalid arguments: get.name: must not be blank",
    ),
    (
      { "create": { "name": "ui", "new_name": "x" } },
      "invalid arguments: create.new_name: unknown field",
    ),
    (
      { "update": { "name": "ui", "owner": 1 } },
      "invalid arguments: update.owner: expected a string",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_components", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "components: readonly mode keeps list and get only" {
  let fake = FakeComponents::new()
  let tools = components_tools(fake, mode=Readonly)
  for action in ["create", "update", "delete"] {
    let called = call_tool(
      tools,
      "trac_components",
      Json::object(Map([(action, { "name": "ui" })])),
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
  assert_true(text.has_prefix("List and show Trac ticket components."))
  assert_false(text.contains("`update`"))
}

///|
async test "components: a Trac failure becomes a failure payload" {
  let tools = components_tools(
    FakeComponents::new(
      failure=Fault(code=403, message="TICKET_ADMIN privileges are required"),
    ),
  )
  let called = call_tool(tools, "trac_components", {
    "delete": { "name": "ui" },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":403,\"errors\":[\"TICKET_ADMIN privileges are required\"]}",
  )
}
