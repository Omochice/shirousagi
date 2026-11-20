///|
struct FakeSearch {
  calls : Array[String]
  failure : @trac.TracError?
}

///|
fn FakeSearch::new(failure? : @trac.TracError) -> FakeSearch {
  { calls: [], failure, }
}

///|
fn FakeSearch::record(
  self : FakeSearch,
  call : String,
) -> Unit raise @trac.TracError {
  self.calls.push(call)
  if self.failure is Some(error) {
    raise error
  }
}

///|
impl SearchPort for FakeSearch with fn search_filters(self) {
  self.record("filters")
  [{ "name": "ticket", "label": "Tickets" }]
}

///|
impl SearchPort for FakeSearch with fn search(self, query, filters?) {
  let scope = match filters {
    Some(filters) => " in \{filters.join(",")}"
    None => ""
  }
  self.record("search \{query}\{scope}")
  [
    {
      "href": "/ticket/3",
      "title": "#3: login fails",
      "date": "2026-11-20T19:53:23Z",
      "author": "alice",
      "excerpt": "cannot log in",
    },
  ]
}

///|
async test "search forwards the query and the filters" {
  let fake = FakeSearch::new()
  let tools = [search_tool(fake)]
  let called = call_tool(tools, "trac_search", {
    "search": { "query": "login" },
  })
  assert_eq(called.is_error, false)
  assert_eq(
    called.text,
    "[{\"href\":\"/ticket/3\",\"title\":\"#3: login fails\",\"date\":\"2026-11-20T19:53:23Z\",\"author\":\"alice\",\"excerpt\":\"cannot log in\"}]",
  )
  ignore(
    call_tool(tools, "trac_search", {
      "search": { "query": "login", "filters": ["ticket", "wiki"] },
    }),
  )
  assert_eq(fake.calls, ["search login", "search login in ticket,wiki"])
}

///|
async test "filters answers the filter names" {
  let fake = FakeSearch::new()
  let called = call_tool([search_tool(fake)], "trac_search", { "filters": {} })
  assert_eq(called.text, "[{\"name\":\"ticket\",\"label\":\"Tickets\"}]")
}

///|
async test "search: validation reports the exact message for each rule" {
  let fake = FakeSearch::new()
  let tools = [search_tool(fake)]
  let cases : Array[(Json, String)] = [
    (
      { "search": { "query": " " } },
      "invalid arguments: search.query: must not be blank",
    ),
    (
      { "search": { "query": "a", "filters": [] } },
      "invalid arguments: search.filters: must have at least 1 items",
    ),
    (
      { "search": { "query": "a", "filters": [""] } },
      "invalid arguments: search.filters.0: must not be blank",
    ),
  ]
  for entry in cases {
    let called = call_tool(tools, "trac_search", entry.0)
    assert_eq(called.is_error, true)
    assert_true(
      called.text.contains(entry.1),
      msg="\{called.text} lacks \{entry.1}",
    )
  }
  assert_eq(fake.calls, [])
}

///|
async test "search: a Trac failure becomes a failure payload" {
  let tools = [search_tool(FakeSearch::new(failure=Http(status=401)))]
  let called = call_tool(tools, "trac_search", { "search": { "query": "a" } })
  assert_eq(called.is_error, true)
  assert_eq(
    called.text,
    "{\"status\":401,\"errors\":[\"HTTP 401: the username or password was rejected\"]}",
  )
}
