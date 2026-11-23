///|
test "method names and signatures are read as text in Trac's order" {
  assert_eq(
    strings_of("system.methodSignature", ["string,string", "string,string,int"]),
    ["string,string", "string,string,int"],
  )
}

///|
test "a list holding anything but text is an unknown shape" {
  for json in [Json("ticket.get"), [Json::null()]] {
    try strings_of("system.listMethods", json) catch {
      Decode(message~) =>
        assert_true(message.contains("system.listMethods"), msg=message)
      error => fail("\{error}")
    } noraise {
      _ => fail("\{json.stringify()} was read as text")
    }
  }
}
