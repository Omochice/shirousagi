///|
struct FakeWiki {
  calls : Array[String]
  puts : Array[(String, String, String?)]
  failure : @trac.TracError?
}

///|
fn FakeWiki::new(failure? : @trac.TracError) -> FakeWiki {
  { calls: [], puts: [], failure, }
}

///|
fn FakeWiki::record(
  self : FakeWiki,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
fn version_label(version : Int32?) -> String {
  match version {
    Some(version) => "@\{version}"
    None => ""
  }
}

///|
impl WikiPort for FakeWiki with fn wiki_page_names(self) {
  self.record("names")
  ["WikiStart", "Guide/Install"]
}

///|
impl WikiPort for FakeWiki with fn get_wiki_page(self, name, version?) {
  self.record("get \{name}\{version_label(version)}")
  "= Welcome =\nHello"
}

///|
impl WikiPort for FakeWiki with fn wiki_page_info(self, name, version?) {
  self.record("info \{name}\{version_label(version)}")
  { "name": Json(name), "version": 2, "author": "alice" }
}

///|
impl WikiPort for FakeWiki with fn recent_wiki_changes(self, since) {
  self.record("recent \{since}")
  [{ "name": "WikiStart", "version": 2 }]
}

///|
impl WikiPort for FakeWiki with fn wiki_page_html(self, name, version?) {
  self.record("html \{name}\{version_label(version)}")
  "<html><body><h1>Welcome</h1></body></html>"
}

///|
impl WikiPort for FakeWiki with fn render_wiki(self, text) {
  self.record("render \{text}")
  "<h1>hi</h1>"
}

///|
impl WikiPort for FakeWiki with fn put_wiki_page(self, name, text~, comment?) {
  self.record("put \{name}")
  self.puts.push((name, text, comment))
}

///|
impl WikiPort for FakeWiki with fn delete_wiki_page(self, name, version?) {
  self.record("delete \{name}\{version_label(version)}")
}

///|
fn wiki_tools(fake : FakeWiki, mode~ : Mode = Full) -> Array[@mcp.Tool] {
  [wiki_tool(fake, mode)]
}

///|
async test "the read actions reach their port methods and answer their JSON" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake)
  let listed = call_tool(tools, "trac_wiki", { "list": {} })
  assert_eq(listed.text, "[\"WikiStart\",\"Guide/Install\"]")
  let got = call_tool(tools, "trac_wiki", { "get": { "name": "WikiStart" } })
  assert_eq(got.is_error, false)
  assert_eq(got.text, "\"= Welcome =\\nHello\"")
  let old = call_tool(tools, "trac_wiki", {
    "info": { "name": "WikiStart", "version": 1 },
  })
  assert_eq(
    old.text,
    "{\"name\":\"WikiStart\",\"version\":2,\"author\":\"alice\"}",
  )
  let recent = call_tool(tools, "trac_wiki", {
    "recent_changes": { "since": "2026-11-20T00:00:00Z" },
  })
  assert_eq(recent.text, "[{\"name\":\"WikiStart\",\"version\":2}]")
  assert_eq(fake.calls, [
    "names", "get WikiStart", "info WikiStart@1", "recent 2026-11-20T00:00:00Z",
  ])
}

///|
async test "put maps the text and comment and answers ok" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake)
  let called = call_tool(tools, "trac_wiki", {
    "put": {
      "name": "Guide/Install",
      "text": "= Install =",
      "comment": "first",
    },
  })
  assert_eq(called.text, "{\"ok\":true}")
  ignore(
    call_tool(tools, "trac_wiki", { "put": { "name": "Empty", "text": "" } }),
  )
  assert_eq(fake.puts, [
    ("Guide/Install", "= Install =", Some("first")),
    ("Empty", "", None),
  ])
}

///|
async test "delete removes a page or one version of it" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake)
  let whole = call_tool(tools, "trac_wiki", { "delete": { "name": "Old" } })
  assert_eq(whole.text, "{\"ok\":true}")
  ignore(
    call_tool(tools, "trac_wiki", { "delete": { "name": "Old", "version": 3 } }),
  )
  assert_eq(fake.calls, ["delete Old", "delete Old@3"])
}

///|
async test "wiki: validation reports the exact message for each rule" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake)
  let cases : Array[(Json, String)] = [
    (
      { "get": { "name": " " } },
      "invalid arguments: get.name: must not be blank",
    ),
    (
      { "info": { "name": "a", "version": 0 } },
      "invalid arguments: info.version: must be at least 1",
    ),
    (
      { "recent_changes": { "since": "2026-11-20" } },
      "invalid arguments: recent_changes.since: must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
    ),
    ({ "put": { "name": "a" } }, "invalid arguments: put.text: is required"),
    (
      { "delete": { "name": "" } },
      "invalid arguments: delete.name: must not be blank",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_wiki", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "wiki: readonly mode makes put and delete unknown" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake, mode=Readonly)
  for action in ["put", "delete"] {
    let called = call_tool(
      tools,
      "trac_wiki",
      Json::object(Map([(action, { "name": "a", "text": "" })])),
    )
    assert_eq(
      called.text,
      "{\"status\":0,\"errors\":[\"invalid arguments: unknown action `\{action}`, one of `list`, `get`, `info`, `recent_changes`, `html` and `render`\"]}",
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
  assert_eq(actions.keys().collect(), [
    "list", "get", "info", "recent_changes", "html", "render",
  ])
  assert_true(text.has_prefix("List and show Trac wiki pages."))
  assert_false(text.contains("`put`"))
}

///|
async test "wiki: a Trac failure becomes a failure payload" {
  let tools = wiki_tools(
    FakeWiki::new(
      failure=Fault(code=404, message="Wiki page \"X\" does not exist"),
    ),
  )
  let requests : Array[Json] = [
    { "get": { "name": "X" } },
    { "put": { "name": "X", "text": "" } },
    { "delete": { "name": "X" } },
  ]
  for arguments in requests {
    let called = call_tool(tools, "trac_wiki", arguments)
    assert_eq(called.is_error, true)
    assert_eq(
      called.text,
      "{\"status\":404,\"errors\":[\"Wiki page \\\"X\\\" does not exist\"]}",
    )
  }
}

///|
async test "html and render reach their port methods and answer their JSON" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake, mode=Readonly)
  let page = call_tool(tools, "trac_wiki", {
    "html": { "name": "WikiStart", "version": 2 },
  })
  assert_eq(page.text, "\"<html><body><h1>Welcome</h1></body></html>\"")
  let rendered = call_tool(tools, "trac_wiki", { "render": { "text": "= hi" } })
  assert_eq(rendered.text, "\"<h1>hi</h1>\"")
  assert_eq(fake.calls, ["html WikiStart@2", "render = hi"])
}

///|
async test "wiki: render needs the text, and html a valid version" {
  let fake = FakeWiki::new()
  let tools = wiki_tools(fake)
  let cases : Array[(Json, String)] = [
    ({ "render": {} }, "invalid arguments: render.text: is required"),
    (
      { "html": { "name": "WikiStart", "version": 0 } },
      "invalid arguments: html.version: must be at least 1",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_wiki", entry.0)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}
