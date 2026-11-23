///|
test "serve takes an endpoint and an optional readonly flag" {
  assert_eq(
    @cli.parse_arguments(argv=["serve", "--endpoint", "https://t.example.com"]),
    @cli.Serve(endpoint="https://t.example.com", read_only=false),
  )
  @debug.debug_inspect(
    @cli.parse_arguments(argv=[
      "serve", "--endpoint", "https://t.example.com", "--readonly",
    ]),
    content="Serve(endpoint=\"https://t.example.com\", read_only=true)",
  )
}

///|
test "login takes an endpoint and a username, logout and list" {
  assert_eq(
    @cli.parse_arguments(argv=[
      "login", "--endpoint", "http://localhost:8000/demo", "--username", "alice",
    ]),
    @cli.Login(endpoint="http://localhost:8000/demo", username="alice"),
  )
  assert_eq(
    @cli.parse_arguments(argv=[
      "logout", "--endpoint", "http://localhost:8000/demo",
    ]),
    @cli.Logout(endpoint="http://localhost:8000/demo"),
  )
  assert_eq(@cli.parse_arguments(argv=["list"]), @cli.List)
}

///|
test "a missing option or subcommand is rejected with the usage" {
  for
    argv in [
      ["serve"],
      ["login"],
      ["login", "--endpoint", "https://t.example.com"],
      ["login", "--username", "alice"],
      ["logout"],
      ["frobnicate"],
    ] {
    try @cli.parse_arguments(argv~) catch {
      error =>
        assert_true(
          error.to_string().contains("\nUsage: shirousagi"),
          msg="\{argv.join(" ")} was rejected without the usage: \{error}",
        )
    } noraise {
      _ => fail("\{argv.join(" ")} was accepted")
    }
  }
}

///|
test "the password is never an option" {
  try
    @cli.parse_arguments(argv=[
      "login", "--endpoint", "https://t.example.com", "--username", "alice", "--password",
      "secret",
    ])
  catch {
    _ => ()
  } noraise {
    _ => fail("--password was accepted")
  }
}
