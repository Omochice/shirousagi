///|
test "each kind names its own RPC methods" {
  let kinds : Array[Kind] = [Type, Resolution, Priority, Severity]
  inspect(
    kinds.map(kind => kind.methods()).join(" "),
    content="ticket.type ticket.resolution ticket.priority ticket.severity",
  )
}

///|
test "a list of names keeps Trac's order" {
  assert_eq(strings_of("ticket.priority.getAll", ["blocker", "major"]), [
    "blocker", "major",
  ])
}

///|
test "a list holding anything but strings is an unknown shape" {
  for json in [Json("major"), [3]] {
    try strings_of("ticket.priority.getAll", json) catch {
      Decode(message~) =>
        assert_true(message.contains("ticket.priority.getAll"), msg=message)
      error => fail("\{error}")
    } noraise {
      _ => fail("\{json.stringify()} was read as names")
    }
  }
}
