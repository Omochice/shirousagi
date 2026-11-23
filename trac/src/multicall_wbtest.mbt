///|
test "each outcome is the result or the fault of its own call" {
  let reply =
    #|{"result": [{"result": ["blocker"], "error": null, "id": "0"}, {"result": null, "id": "1", "error": {"name": "JSONRPCError", "code": 404, "message": "Ticket 99999 does not exist."}}], "error": null, "id": 1}
  let outcomes = outcomes_of(2, interpret(200, reply))
  guard outcomes
    is [Ok(Array([String("blocker")])), Err(Fault(code=404, message~))] else {
    fail("the outcomes were not decoded per call")
  }
  inspect(message, content="Ticket 99999 does not exist.")
}

///|
test "datetimes inside a batch result are UTC text" {
  let reply =
    #|{"result": [{"result": {"__jsonclass__": ["datetime", "2026-11-21T05:24:44"]}, "error": null, "id": "0"}], "error": null, "id": 1}
  guard outcomes_of(1, interpret(200, reply)) is [Ok(String(text))] else {
    fail("the datetime was not converted")
  }
  inspect(text, content="2026-11-21T05:24:44Z")
}

///|
test "an answer that does not pair one outcome with each call is an unknown shape" {
  let cases : Array[(Int32, Json)] = [
    (2, [{ "result": 1, "error": Json::null(), "id": "0" }]),
    (
      2,
      [
        { "result": 1, "error": Json::null(), "id": "1" },
        { "result": 2, "error": Json::null(), "id": "0" },
      ],
    ),
    (1, [{ "result": 1, "id": "0" }]),
    (1, { "result": 1 }),
  ]
  for entry in cases {
    try outcomes_of(entry.0, entry.1) catch {
      Decode(..) => ()
      error => fail("\{error}")
    } noraise {
      _ => fail("\{entry.1.stringify()} was accepted")
    }
  }
}

///|
test "every call of the batch is one parameter with its index as id" {
  inspect(
    envelope("system.multicall", [
      { "method": "ticket.get", "params": [1], "id": "0" },
    ]).stringify(),
    content=(
      #|{"method":"system.multicall","params":[{"method":"ticket.get","params":[1],"id":"0"}],"id":1}
    ),
  )
}
