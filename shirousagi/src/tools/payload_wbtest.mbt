///|
test "a success holds the JSON of the value" {
  let result = success(["a", "b"])
  assert_eq(result.is_error, false)
  assert_eq(text_of(result), "[\"a\",\"b\"]")
}

///|
test "success_ok answers ok" {
  assert_eq(text_of(success_ok()), "{\"ok\":true}")
}

///|
test "a fault keeps Trac's code and message" {
  let result = failure_of(Fault(code=404, message="Ticket 9 does not exist."))
  assert_eq(result.is_error, true)
  assert_eq(
    text_of(result),
    "{\"status\":404,\"errors\":[\"Ticket 9 does not exist.\"]}",
  )
}

///|
test "an HTTP failure keeps its status and explains a rejected login" {
  assert_eq(
    text_of(failure_of(Http(status=401))),
    "{\"status\":401,\"errors\":[\"HTTP 401: the username or password was rejected\"]}",
  )
  assert_eq(
    text_of(failure_of(Http(status=502))),
    "{\"status\":502,\"errors\":[\"HTTP 502\"]}",
  )
}

///|
test "a transport error has status 0" {
  assert_eq(
    text_of(failure_of(Transport(message="connection refused"))),
    "{\"status\":0,\"errors\":[\"connection refused\"]}",
  )
}

///|
test "a request the SDK refused to send has status 0" {
  assert_eq(
    text_of(
      failure_of(InvalidArgument(message="the username must not contain `:`")),
    ),
    "{\"status\":0,\"errors\":[\"the username must not contain `:`\"]}",
  )
}

///|
test "a decode error has status 0 and keeps its message" {
  assert_eq(
    text_of(failure_of(Decode(message="The server answered, but not"))),
    "{\"status\":0,\"errors\":[\"The server answered, but not\"]}",
  )
}

///|
test "a local failure has status 0" {
  assert_eq(
    text_of(local_failure(["a", "b"])),
    "{\"status\":0,\"errors\":[\"a\",\"b\"]}",
  )
}

///|
async test "respond maps a raised error to a failure" {
  let result : @mcp.ToolResult = respond(fn() -> Int32 raise @trac.TracError {
    raise Fault(code=403, message="TICKET_VIEW privileges are required")
  })
  assert_eq(result.is_error, true)
  assert_eq(
    text_of(result),
    "{\"status\":403,\"errors\":[\"TICKET_VIEW privileges are required\"]}",
  )
}

///|
async test "respond_ok answers ok when the call returns" {
  let result = respond_ok(fn() raise @trac.TracError {
    if false {
      raise Transport(message="unused")
    }
  })
  assert_eq(result.is_error, false)
  assert_eq(text_of(result), "{\"ok\":true}")
}

///|
test "on_invalid prefixes each message" {
  let error = @schema.SchemaError::Many([
    Invalid(path=["get", "id"], message="must be at least 1"),
    Invalid(path=[], message="expected an object"),
  ])
  assert_eq(
    text_of(on_invalid(error)),
    "{\"status\":0,\"errors\":[\"invalid arguments: get.id: must be at least 1\",\"invalid arguments: expected an object\"]}",
  )
}

///|
test "describe_crud_tool drops the write verbs in readonly mode" {
  inspect(
    describe_crud_tool("tickets", Readonly, lines=[]),
    content=(
      #|List and show Trac tickets.
      #|Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{"<operation>": {...}}`.
    ),
  )
  inspect(
    describe_crud_tool("milestones", Full, lines=[]),
    content=(
      #|Create, read, update, and delete Trac milestones.
      #|Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{"<operation>": {...}}`.
    ),
  )
}

///|
test "describe_crud_tool puts the extra lines between the summary and the hint" {
  inspect(
    describe_crud_tool("tickets", Full, lines=["first", "second"]),
    content=(
      #|Create, read, update, and delete Trac tickets.
      #|first
      #|second
      #|Pass exactly one key, the operation name, whose value is an object of that operation's arguments: `{"<operation>": {...}}`.
    ),
  )
}

///|
test "string_map takes any keys with string values" {
  let schema = string_map()
  let parsed = schema.parse({ "owner": "alice", "custom_x": "1" })
  assert_eq(parsed.get("owner"), Some("alice"))
  assert_eq(parsed.get("custom_x"), Some("1"))
  assert_true(schema.parse({}).is_empty())
}

///|
test "string_map names every key whose value is not a string" {
  try string_map().parse({ "a": 1, "b": "ok", "c": true }) catch {
    error =>
      assert_eq(error.messages(), [
        "a: expected a string", "c: expected a string",
      ])
  } noraise {
    _ => fail("non-string values were accepted")
  }
  try string_map().parse(Json::array([])) catch {
    error => assert_eq(error.messages(), ["expected an object"])
  } noraise {
    _ => fail("an array was accepted")
  }
}
