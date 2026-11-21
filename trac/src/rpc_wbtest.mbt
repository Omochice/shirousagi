///|
test "a result has its datetimes replaced by UTC text" {
  let reply =
    #|{"result": [1, {"__jsonclass__": ["datetime", "2026-11-20T19:53:23.200107"]}, {"summary": "first", "time": {"__jsonclass__": ["datetime", "2026-11-20T19:53:23.200107"]}, "_ts": "1795204403200107"}], "error": null, "id": 3}
  inspect(
    interpret(200, reply).stringify(),
    content=(
      #|[1,"2026-11-20T19:53:23.200107Z",{"summary":"first","time":"2026-11-20T19:53:23.200107Z","_ts":"1795204403200107"}]
    ),
  )
}

///|
test "a null result is returned as null" {
  inspect(
    interpret(200, "{\"result\": null, \"error\": null, \"id\": 1}").stringify(),
    content="null",
  )
}

///|
test "a fault carries Trac's code and message" {
  let reply =
    #|{"result": null, "id": 4, "error": {"name": "JSONRPCError", "code": 404, "message": "Ticket 999 does not exist."}}
  try interpret(200, reply) catch {
    error =>
      @debug.debug_inspect(
        error,
        content=(
          #|Fault(code=404, message="Ticket 999 does not exist.")
        ),
      )
  } noraise {
    _ => fail("a fault was returned as a result")
  }
}

///|
test "a rejected login is an HTTP failure whatever the body says" {
  try interpret(401, "") catch {
    error => @debug.debug_inspect(error, content="Http(status=401)")
  } noraise {
    _ => fail("a 401 was returned as a result")
  }
}

///|
test "an answer that is not a JSON-RPC reply is a decode failure that quotes nothing of the body" {
  for body in ["<html>secret</html>", "{\"jsonrpc\": \"2.0\"}", "[]"] {
    try interpret(200, body) catch {
      Decode(message~) => assert_false(message.contains("secret"))
      error => fail("\{body} raised \{error}")
    } noraise {
      _ => fail("\{body} was returned as a result")
    }
  }
}

///|
test "text that already carries Z is not given a second one" {
  inspect(
    from_wire({ "__jsonclass__": ["datetime", "2026-11-20T19:53:23Z"] }).stringify(),
    content="\"2026-11-20T19:53:23Z\"",
  )
}

///|
test "a datetime parameter is wrapped as TracXMLRPC expects" {
  inspect(
    datetime("2026-11-21T00:00:00+09:00").stringify(),
    content=(
      #|{"__jsonclass__":["datetime","2026-11-21T00:00:00+09:00"]}
    ),
  )
}

///|
test "a binary parameter is wrapped as base64 and read back byte for byte" {
  let bytes = b"\xff\x00a"
  let wire = binary(bytes)
  inspect(
    wire.stringify(),
    content=(
      #|{"__jsonclass__":["binary","/wBh"]}
    ),
  )
  assert_eq(bytes_of(wire), Some(bytes))
}

///|
test "a binary result survives interpret untouched" {
  let reply =
    #|{"result": {"__jsonclass__": ["binary", "/w=="]}, "error": null, "id": 1}
  assert_eq(bytes_of(interpret(200, reply)), Some(b"\xff"))
}

///|
test "base64 wrapped over lines is read as one value" {
  assert_eq(
    bytes_of({ "__jsonclass__": ["binary", "/wBh\n/w==\n"] }),
    Some(b"\xff\x00a\xff"),
  )
}

///|
test "anything but a well-formed binary value is no bytes" {
  for
    json in [
      Json("/w=="),
      { "__jsonclass__": ["datetime", "2026-11-21T00:00:00"] },
      { "__jsonclass__": ["binary", "*"] },
    ] {
    assert_eq(bytes_of(json), None, msg=json.stringify())
  }
}

///|
test "the envelope names the method and its positional parameters" {
  inspect(
    envelope("ticket.get", [1]).stringify(),
    content=(
      #|{"method":"ticket.get","params":[1],"id":1}
    ),
  )
}
