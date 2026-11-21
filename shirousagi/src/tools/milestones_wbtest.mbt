///|
struct FakeMilestones {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeMilestones::new(failure? : @trac.TracError) -> FakeMilestones {
  { calls: [], failure, }
}

///|
fn FakeMilestones::record(
  self : FakeMilestones,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
/// `Changes` derives nothing to compare it by, so the fakes log it as text.
fn changes_label(changes : @milestones.Changes) -> String {
  fn moment(moment : @trac.Moment?) -> String {
    match moment {
      Some(At(iso)) => iso
      Some(Unset) => "unset"
      None => "-"
    }
  }

  let name = changes.name.unwrap_or("-")
  let description = changes.description.unwrap_or("-")
  "name=\{name} due=\{moment(changes.due)} completed=\{moment(changes.completed)} description=\{description}"
}

///|
impl MilestonePort for FakeMilestones with fn milestone_names(self) {
  self.record("names")
  ["1.0", "2.0"]
}

///|
impl MilestonePort for FakeMilestones with fn get_milestone(self, name) {
  self.record("get \{name}")
  {
    "name": Json(name),
    "due": "2026-12-31T00:00:00Z",
    "completed": Json::null(),
  }
}

///|
impl MilestonePort for FakeMilestones with fn create_milestone(
  self,
  name,
  changes,
) {
  self.record("create \{name} \{changes_label(changes)}")
}

///|
impl MilestonePort for FakeMilestones with fn update_milestone(
  self,
  name,
  changes,
) {
  self.record("update \{name} \{changes_label(changes)}")
}

///|
impl MilestonePort for FakeMilestones with fn delete_milestone(self, name) {
  self.record("delete \{name}")
}

///|
fn milestones_tools(
  fake : FakeMilestones,
  mode~ : Mode = Full,
) -> Array[@mcp.Tool] {
  [milestones_tool(fake, mode)]
}

///|
async test "list and get reach their port methods and answer their JSON" {
  let fake = FakeMilestones::new()
  let tools = milestones_tools(fake)
  let listed = call_tool(tools, "trac_milestones", { "list": {} })
  assert_eq(listed.text, "[\"1.0\",\"2.0\"]")
  let got = call_tool(tools, "trac_milestones", { "get": { "name": "1.0" } })
  assert_eq(
    got.text,
    "{\"name\":\"1.0\",\"due\":\"2026-12-31T00:00:00Z\",\"completed\":null}",
  )
  assert_eq(fake.calls, ["names", "get 1.0"])
}

///|
async test "create maps every argument and answers ok" {
  let fake = FakeMilestones::new()
  let tools = milestones_tools(fake)
  let called = call_tool(tools, "trac_milestones", {
    "create": {
      "name": "1.0",
      "due": "2026-12-31T00:00:00Z",
      "completed": "2026-12-30T12:00:00+09:00",
      "description": "First release",
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"ok\":true}")
  ignore(call_tool(tools, "trac_milestones", { "create": { "name": "2.0" } }))
  assert_eq(fake.calls, [
    "create 1.0 name=- due=2026-12-31T00:00:00Z completed=2026-12-30T12:00:00+09:00 description=First release",
    "create 2.0 name=- due=- completed=- description=-",
  ])
}

///|
async test "update renames, sets, clears, and leaves fields alone" {
  let fake = FakeMilestones::new()
  let tools = milestones_tools(fake)
  let called = call_tool(tools, "trac_milestones", {
    "update": {
      "name": "1.0",
      "new_name": "1.0.0",
      "due": "2027-01-31T00:00:00Z",
      "completed": Json::null(),
    },
  })
  assert_eq(called.text, "{\"ok\":true}")
  ignore(
    call_tool(tools, "trac_milestones", {
      "update": { "name": "1.0", "due": Json::null(), "description": "" },
    }),
  )
  assert_eq(fake.calls, [
    "update 1.0 name=1.0.0 due=2027-01-31T00:00:00Z completed=unset description=-",
    "update 1.0 name=- due=unset completed=- description=",
  ])
}

///|
async test "milestones: delete answers ok" {
  let fake = FakeMilestones::new()
  let called = call_tool(milestones_tools(fake), "trac_milestones", {
    "delete": { "name": "1.0" },
  })
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.calls, ["delete 1.0"])
}

///|
async test "milestones: validation reports the exact message for each rule" {
  let fake = FakeMilestones::new()
  let tools = milestones_tools(fake)
  let cases : Array[(Json, String)] = [
    (
      { "get": { "name": " " } },
      "invalid arguments: get.name: must not be blank",
    ),
    (
      { "create": { "name": "1.0", "due": Json::null() } },
      "invalid arguments: create.due: expected a string",
    ),
    (
      { "create": { "name": "1.0", "due": "2026-12-31" } },
      "invalid arguments: create.due: must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
    ),
    (
      { "update": { "name": "1.0", "completed": "soon" } },
      "invalid arguments: update.completed: must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
    ),
    (
      { "update": { "name": "1.0", "new_name": "" } },
      "invalid arguments: update.new_name: must not be blank",
    ),
    (
      { "create": { "name": "1.0", "new_name": "x" } },
      "invalid arguments: create.new_name: unknown field",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_milestones", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "milestones: readonly mode makes the write actions unknown" {
  let fake = FakeMilestones::new()
  let tools = milestones_tools(fake, mode=Readonly)
  for action in ["create", "update", "delete"] {
    let called = call_tool(
      tools,
      "trac_milestones",
      Json::object(Map([(action, { "name": "1.0" })])),
    )
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `\{action}`, one of `list` and `get`\"]}",
    )
  }
  assert_eq(fake.calls, [])
  let listed = list_tools(tools)
  guard listed
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
    fail("no keyed schema in \{listed.stringify()}")
  }
  assert_eq(actions.keys().collect(), ["list", "get"])
  assert_true(text.has_prefix("List and show Trac milestones."))
  assert_false(text.contains("`update`"))
}

///|
async test "milestones: the update schema advertises null for the dates" {
  let listed = list_tools(milestones_tools(FakeMilestones::new()))
  let text = listed.stringify()
  assert_true(text.contains("\"completed\":{\"anyOf\":["), msg=text)
  assert_true(text.contains("{\"type\":\"null\"}"), msg=text)
}

///|
async test "milestones: a Trac failure becomes a failure payload" {
  let tools = milestones_tools(
    FakeMilestones::new(
      failure=Fault(
        code=403,
        message="MILESTONE_DELETE privileges are required",
      ),
    ),
  )
  let requests : Array[Json] = [
    { "list": {} },
    { "create": { "name": "1.0" } },
    { "delete": { "name": "1.0" } },
  ]
  for arguments in requests {
    let called = call_tool(tools, "trac_milestones", arguments)
    assert_eq(called.is_error, true)
    assert_eq(
      called.text,
      "{\"status\":403,\"errors\":[\"MILESTONE_DELETE privileges are required\"]}",
    )
  }
}
