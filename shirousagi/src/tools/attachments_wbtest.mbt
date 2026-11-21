///|
struct FakeAttachments {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeAttachments::new(failure? : @trac.TracError) -> FakeAttachments {
  { calls: [], failure, }
}

///|
fn FakeAttachments::record(
  self : FakeAttachments,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn target_label(target : @attachments.Target) -> String {
  match target {
    Ticket(id) => "ticket:\{id}"
    Wiki(page) => "wiki:\{page}"
  }
}

///|
impl AttachmentPort for FakeAttachments with fn attachments(self, target) {
  self.record("list \{target_label(target)}")
  [{ "filename": "a.bin" }]
}

///|
impl AttachmentPort for FakeAttachments with fn get_attachment(
  self,
  target,
  filename,
) {
  self.record("get \{target_label(target)} \{filename}")
  b"\xff\x00"
}

///|
impl AttachmentPort for FakeAttachments with fn put_attachment(
  self,
  target,
  filename,
  content,
  description?,
  replace?,
) {
  let description = description.unwrap_or("-")
  let replace = match replace {
    Some(true) => "true"
    Some(false) => "false"
    None => "-"
  }
  self.record(
    "put \{target_label(target)} \{filename} \{@base64.encode(content)} description=\{description} replace=\{replace}",
  )
  "a.2.bin"
}

///|
impl AttachmentPort for FakeAttachments with fn delete_attachment(
  self,
  target,
  filename,
) {
  self.record("delete \{target_label(target)} \{filename}")
}

///|
fn attachments_tools(
  fake : FakeAttachments,
  mode~ : Mode = Full,
) -> Array[@mcp.Tool] {
  [attachments_tool(fake, mode)]
}

///|
async test "list and get name the ticket or the page and answer base64 content" {
  let fake = FakeAttachments::new()
  let tools = attachments_tools(fake)
  let listed = call_tool(tools, "trac_attachments", { "list": { "ticket": 3 } })
  assert_eq(listed.text, "[{\"filename\":\"a.bin\"}]")
  let got = call_tool(tools, "trac_attachments", {
    "get": { "page": "Guide/Install", "filename": "a.bin" },
  })
  assert_eq(got.text, "{\"filename\":\"a.bin\",\"content_base64\":\"/wA=\"}")
  assert_eq(fake.calls, ["list ticket:3", "get wiki:Guide/Install a.bin"])
}

///|
async test "put decodes the content and answers the stored filename" {
  let fake = FakeAttachments::new()
  let tools = attachments_tools(fake)
  let called = call_tool(tools, "trac_attachments", {
    "put": {
      "ticket": 3,
      "filename": "a.bin",
      "content_base64": "/w==",
      "description": "one byte",
      "replace": true,
    },
  })
  assert_eq(called.is_error, false)
  assert_eq(called.text, "{\"filename\":\"a.2.bin\"}")
  ignore(
    call_tool(tools, "trac_attachments", {
      "put": { "page": "WikiStart", "filename": "e", "content_base64": "" },
    }),
  )
  assert_eq(fake.calls, [
    "put ticket:3 a.bin /w== description=one byte replace=true", "put wiki:WikiStart e  description=- replace=-",
  ])
}

///|
async test "attachments: delete answers ok" {
  let fake = FakeAttachments::new()
  let called = call_tool(attachments_tools(fake), "trac_attachments", {
    "delete": { "page": "WikiStart", "filename": "a.bin" },
  })
  assert_eq(called.text, "{\"ok\":true}")
  assert_eq(fake.calls, ["delete wiki:WikiStart a.bin"])
}

///|
async test "attachments: validation reports the exact message for each rule" {
  let fake = FakeAttachments::new()
  let tools = attachments_tools(fake)
  let cases : Array[(Json, String)] = [
    (
      { "list": {} },
      "invalid arguments: list: one of `ticket` and `page` is required",
    ),
    (
      { "list": { "ticket": 3, "page": "WikiStart" } },
      "invalid arguments: list: `ticket` and `page` cannot be given together",
    ),
    (
      { "list": { "ticket": 0 } },
      "invalid arguments: list.ticket: must be at least 1",
    ),
    (
      { "list": { "page": " " } },
      "invalid arguments: list.page: must not be blank",
    ),
    (
      { "get": { "ticket": 3, "filename": "" } },
      "invalid arguments: get.filename: must not be blank",
    ),
    (
      {
        "put": { "ticket": 3, "filename": "a", "content_base64": "not base64!" },
      },
      "invalid arguments: put.content_base64: must be base64 text",
    ),
    (
      { "put": { "ticket": 3, "filename": "a", "content_base64": 1 } },
      "invalid arguments: put.content_base64: expected a string",
    ),
    (
      { "put": { "ticket": 3, "filename": "a" } },
      "invalid arguments: put.content_base64: is required",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_attachments", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "attachments: readonly mode keeps list and get only" {
  let fake = FakeAttachments::new()
  let tools = attachments_tools(fake, mode=Readonly)
  for action in ["put", "delete"] {
    let called = call_tool(
      tools,
      "trac_attachments",
      Json::object(
        Map([(action, { "ticket": 3, "filename": "a", "content_base64": "" })]),
      ),
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
  assert_true(text.has_prefix("List and show Trac attachments."))
  assert_false(text.contains("`put`"))
}

///|
async test "attachments: the schema advertises the owner choice and base64" {
  let text = list_tools(attachments_tools(FakeAttachments::new())).stringify()
  assert_true(
    text.contains(
      "\"oneOf\":[{\"required\":[\"ticket\"]},{\"required\":[\"page\"]}]",
    ),
    msg=text,
  )
  assert_true(text.contains("\"contentEncoding\":\"base64\""), msg=text)
}

///|
async test "attachments: a Trac failure becomes a failure payload" {
  let tools = attachments_tools(
    FakeAttachments::new(
      failure=Fault(
        code=404,
        message="Attachment 'ticket:2: nope' does not exist.",
      ),
    ),
  )
  let called = call_tool(tools, "trac_attachments", {
    "get": { "ticket": 2, "filename": "nope" },
  })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":404,\"errors\":[\"Attachment 'ticket:2: nope' does not exist.\"]}",
  )
}
