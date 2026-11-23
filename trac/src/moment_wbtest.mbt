///|
test "a version answered with time 0 has a null time" {
  inspect(
    unset_dates_as_null(
      "ticket.version.get",
      { "name": "1.0", "time": 0, "description": "" },
      ["time"],
    ).stringify(),
    content=(
      #|{"name":"1.0","time":null,"description":""}
    ),
  )
  inspect(
    unset_dates_as_null(
      "ticket.version.get",
      { "name": "1.0", "time": "2030-01-01T00:00:00Z" },
      ["time"],
    ).stringify(),
    content=(
      #|{"name":"1.0","time":"2030-01-01T00:00:00Z"}
    ),
  )
}

///|
test "a milestone answered with due and completed 0 has both null" {
  inspect(
    unset_dates_as_null(
      "ticket.milestone.get",
      { "name": "m1", "due": 0, "completed": 0, "description": "" },
      ["due", "completed"],
    ).stringify(),
    content=(
      #|{"name":"m1","due":null,"completed":null,"description":""}
    ),
  )
  inspect(
    unset_dates_as_null(
      "ticket.milestone.get",
      { "name": "m1", "due": "2030-01-01T00:00:00Z", "completed": 0 },
      ["due", "completed"],
    ).stringify(),
    content=(
      #|{"name":"m1","due":"2030-01-01T00:00:00Z","completed":null}
    ),
  )
}

///|
test "a 0 under a key that is not a date stays 0" {
  inspect(
    unset_dates_as_null("ticket.version.get", { "time": 0, "count": 0 }, [
      "time",
    ]).stringify(),
    content=(
      #|{"time":null,"count":0}
    ),
  )
}

///|
test "an answer that is not an object is an unknown shape" {
  try
    unset_dates_as_null("ticket.milestone.get", ["m1"], ["due", "completed"])
  catch {
    Decode(message~) =>
      assert_true(message.contains("ticket.milestone.get"), msg=message)
    error => fail("\{error}")
  } noraise {
    _ => fail("an array was read as an object")
  }
}
