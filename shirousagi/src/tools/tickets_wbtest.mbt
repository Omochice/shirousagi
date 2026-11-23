///|
struct FakeTickets {
  calls : Array[String]
  created : Array[(String, String, Map[String, String])]
  updated : Array[(Int32, String?, String?, Map[String, String]?, String?)]
  notified : Array[Bool?]
  failure : @trac.TracError?
}

///|
fn FakeTickets::new(failure? : @trac.TracError) -> FakeTickets {
  { calls: [], created: [], updated: [], notified: [], failure, }
}

///|
fn FakeTickets::record(
  self : FakeTickets,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn fake_ticket(id : Int32) -> Json {
  {
    "id": Json(id),
    "summary": "login fails",
    "status": "new",
    "_ts": "1795204403200107",
  }
}

///|
impl TicketPort for FakeTickets with fn query_tickets(self, query) {
  self.record("query \{query}")
  [3, 5]
}

///|
impl TicketPort for FakeTickets with fn get_ticket(self, id) {
  self.record("get \{id}")
  fake_ticket(id)
}

///|
impl TicketPort for FakeTickets with fn ticket_changelog(self, id) {
  self.record("changelog \{id}")
  [
    {
      "time": "2026-11-20T19:53:23Z",
      "author": "alice",
      "field": "comment",
      "oldvalue": "1",
      "newvalue": "looked at it",
      "permanent": 1,
    },
  ]
}

///|
impl TicketPort for FakeTickets with fn ticket_actions(self, id) {
  self.record("actions \{id}")
  [{ "name": "leave", "label": "leave", "hints": "", "inputs": [] }]
}

///|
impl TicketPort for FakeTickets with fn ticket_fields(self) {
  self.record("fields")
  [{ "name": "summary", "type": "text" }]
}

///|
impl TicketPort for FakeTickets with fn recent_ticket_changes(self, since) {
  self.record("recent_changes \{since}")
  [7]
}

///|
impl TicketPort for FakeTickets with fn create_ticket(
  self,
  summary~,
  description~,
  fields~,
  notify?,
) {
  self.record("create")
  self.created.push((summary, description, fields))
  self.notified.push(notify)
  9
}

///|
impl TicketPort for FakeTickets with fn update_ticket(
  self,
  id,
  comment?,
  action?,
  fields?,
  ts?,
  notify?,
) {
  self.record("update \{id}")
  self.updated.push((id, comment, action, fields, ts))
  self.notified.push(notify)
  fake_ticket(id)
}

///|
impl TicketPort for FakeTickets with fn delete_ticket(self, id) {
  self.record("delete \{id}")
}

///|
fn tickets_tools(fake : FakeTickets, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [tickets_tool(fake, mode)]
}

///|
async test "the read actions reach their port methods and answer their JSON" {
  let fake = FakeTickets::new()
  let tools = tickets_tools(fake)
  let queried = call_tool(tools, "trac_tickets", {
    "query": { "query": "status!=closed&max=0" },
  })
  assert_eq(queried.is_error, false)
  assert_eq(queried.text, "[3,5]")
  let got = call_tool(tools, "trac_tickets", { "get": { "id": 3 } })
  assert_eq(
    got.text,
    "{\"id\":3,\"summary\":\"login fails\",\"status\":\"new\",\"_ts\":\"1795204403200107\"}",
  )
  let changes = call_tool(tools, "trac_tickets", { "changelog": { "id": 3 } })
  assert_true(changes.text.contains("\"newvalue\":\"looked at it\""))
  let actions = call_tool(tools, "trac_tickets", { "actions": { "id": 3 } })
  assert_true(actions.text.contains("\"name\":\"leave\""))
  let fields = call_tool(tools, "trac_tickets", { "fields": {} })
  assert_eq(fields.text, "[{\"name\":\"summary\",\"type\":\"text\"}]")
  let recent = call_tool(tools, "trac_tickets", {
    "recent_changes": { "since": "2026-11-21T09:00:00+09:00" },
  })
  assert_eq(recent.text, "[7]")
  assert_eq(fake.calls, [
    "query status!=closed&max=0", "get 3", "changelog 3", "actions 3", "fields",
    "recent_changes 2026-11-21T09:00:00+09:00",
  ])
}

///|
async test "create maps every argument and answers the new id" {
  let fake = FakeTickets::new()
  let called = call_tool(tickets_tools(fake), "trac_tickets", {
    "create": {
      "summary": "login fails",
      "description": "Steps:",
      "fields": { "type": "defect", "owner": "alice" },
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"id\":9}")
  assert_eq(fake.created, [
    ("login fails", "Steps:", Map([("type", "defect"), ("owner", "alice")])),
  ])
}

///|
async test "create without fields sends none" {
  let fake = FakeTickets::new()
  ignore(
    call_tool(tickets_tools(fake), "trac_tickets", {
      "create": { "summary": "s", "description": "" },
    }),
  )
  assert_eq(fake.created, [("s", "", Map([]))])
}

///|
async test "update maps every argument and answers the updated ticket" {
  let fake = FakeTickets::new()
  let called = call_tool(tickets_tools(fake), "trac_tickets", {
    "update": {
      "id": 3,
      "comment": "fixed in r42",
      "action": "resolve",
      "fields": { "action_resolve_resolve_resolution": "fixed" },
      "ts": "1795204403200107",
    },
  })
  assert_eq(called.is_error, false)
  assert_true(called.text.contains("\"id\":3"))
  assert_eq(fake.updated, [
    (
      3,
      Some("fixed in r42"),
      Some("resolve"),
      Some(Map([("action_resolve_resolve_resolution", "fixed")])),
      Some("1795204403200107"),
    ),
  ])
}

///|
async test "update with only an id leaves the rest to the SDK defaults" {
  let fake = FakeTickets::new()
  ignore(
    call_tool(tickets_tools(fake), "trac_tickets", { "update": { "id": 3 } }),
  )
  assert_eq(fake.updated, [(3, None, None, None, None)])
}

///|
async test "tickets: delete answers ok" {
  let fake = FakeTickets::new()
  let called = call_tool(tickets_tools(fake), "trac_tickets", {
    "delete": { "id": 3 },
  })
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.calls, ["delete 3"])
}

///|
async test "tickets: validation reports the exact message for each rule" {
  let fake = FakeTickets::new()
  let tools = tickets_tools(fake)
  let cases : Array[(Json, String)] = [
    ({ "get": { "id": 0 } }, "invalid arguments: get.id: must be at least 1"),
    ({ "query": {} }, "invalid arguments: query.query: is required"),
    (
      { "create": { "summary": " ", "description": "" } },
      "invalid arguments: create.summary: must not be blank",
    ),
    (
      { "create": { "summary": "s" } },
      "invalid arguments: create.description: is required",
    ),
    (
      { "create": { "summary": "s", "description": "", "fields": { "x": 1 } } },
      "invalid arguments: create.fields.x: expected a string",
    ),
    (
      {
        "create": {
          "summary": "s",
          "description": "",
          "fields": { "summary": "t" },
        },
      },
      "invalid arguments: create.fields: must not set `summary` or `description`; pass them as `summary` and `description`",
    ),
    (
      { "update": { "id": 3, "fields": { "_ts": "1" } } },
      "invalid arguments: update.fields: must not set `action` or `_ts`; pass them as `action` and `ts`",
    ),
    (
      { "update": { "id": 3, "action": "" } },
      "invalid arguments: update.action: must not be blank",
    ),
    ({ "fields": { "id": 1 } }, "invalid arguments: fields.id: unknown field"),
    (
      { "recent_changes": { "since": "yesterday" } },
      "invalid arguments: recent_changes.since: must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_tickets", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "tickets: readonly mode makes the write actions unknown" {
  let fake = FakeTickets::new()
  let tools = tickets_tools(fake, mode=Readonly)
  for action in ["create", "update", "delete"] {
    let called = call_tool(
      tools,
      "trac_tickets",
      Json::object(Map([(action, { "id": 3 })])),
    )
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `\{action}`, one of `query`, `get`, `changelog`, `actions`, `fields` and `recent_changes`\"]}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "tickets: the readonly schema lacks every write action" {
  let listed = list_tools(tickets_tools(FakeTickets::new(), mode=Readonly))
  guard listed
    is {
      "tools": [{ "inputSchema": { "properties": Object(actions), .. }, .. }],
      ..
    } else {
    fail("no keyed schema in \{listed.stringify()}")
  }
  assert_eq(actions.keys().collect(), [
    "query", "get", "changelog", "actions", "fields", "recent_changes",
  ])
  let full = list_tools(tickets_tools(FakeTickets::new()))
  guard full
    is {
      "tools": [{ "inputSchema": { "properties": Object(actions), .. }, .. }],
      ..
    } else {
    fail("no keyed schema in \{full.stringify()}")
  }
  assert_eq(actions.keys().collect(), [
    "query", "get", "changelog", "actions", "fields", "recent_changes", "create",
    "update", "delete",
  ])
}

///|
async test "tickets: the readonly description leaves out update" {
  let listed = list_tools(tickets_tools(FakeTickets::new(), mode=Readonly))
  guard listed is { "tools": [{ "description": String(text), .. }], .. } else {
    fail("no description")
  }
  assert_true(text.has_prefix("List and show Trac tickets."))
  assert_false(text.contains("update"))
}

///|
async test "tickets: a Trac failure becomes a failure payload" {
  let tools = tickets_tools(
    FakeTickets::new(
      failure=Fault(code=404, message="Ticket 3 does not exist."),
    ),
  )
  let requests : Array[Json] = [
    { "get": { "id": 3 } },
    { "create": { "summary": "s", "description": "" } },
    { "update": { "id": 3 } },
    { "delete": { "id": 3 } },
  ]
  for arguments in requests {
    let called = call_tool(tools, "trac_tickets", arguments)
    assert_eq(called.is_error, true)
    assert_eq(
      called.text,
      "{\"status\":404,\"errors\":[\"Ticket 3 does not exist.\"]}",
    )
  }
}

///|
async test "tickets: a rejected login keeps its HTTP status" {
  let tools = tickets_tools(FakeTickets::new(failure=Http(status=401)))
  let called = call_tool(tools, "trac_tickets", { "fields": {} })
  assert_eq(
    called.text,
    "{\"status\":401,\"errors\":[\"HTTP 401: the username or password was rejected\"]}",
  )
}

///|
async test "notify reaches the port only when it is given" {
  let fake = FakeTickets::new()
  let tools = tickets_tools(fake)
  let requests : Array[Json] = [
    { "create": { "summary": "s", "description": "", "notify": true } },
    { "create": { "summary": "s", "description": "" } },
    { "update": { "id": 3, "notify": false } },
    { "update": { "id": 3 } },
  ]
  for arguments in requests {
    assert_eq(call_tool(tools, "trac_tickets", arguments).is_error, false)
  }
  assert_eq(fake.notified, [Some(true), None, Some(false), None])
}

///|
async test "tickets: notify must be a boolean" {
  let fake = FakeTickets::new()
  let called = call_tool(tickets_tools(fake), "trac_tickets", {
    "update": { "id": 3, "notify": "yes" },
  })
  assert_eq(called.is_error, true)
  assert_true(
    called.text.contains("invalid arguments: update.notify: expected a boolean"),
    msg=called.text,
  )
  assert_eq(fake.calls, [])
}
