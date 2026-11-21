///|
test "recent changes answer the ticket ids" {
  assert_eq(ids_of("ticket.getRecentChanges", [3, 1]), [3, 1])
}

///|
test "an id list holding anything but numbers is an unknown shape" {
  for json in [Json("1"), ["1"]] {
    try ids_of("ticket.getRecentChanges", json) catch {
      Decode(message~) =>
        assert_true(message.contains("ticket.getRecentChanges"), msg=message)
      error => fail("\{error}")
    } noraise {
      _ => fail("\{json.stringify()} was read as ids")
    }
  }
}
