///|
test "equivalent endpoints map to one account" {
  inspect(
    @cli.canonicalize_endpoint("https://T.Example.com/"),
    content="https://t.example.com",
  )
  inspect(
    @cli.canonicalize_endpoint("https://t.example.com"),
    content="https://t.example.com",
  )
  inspect(
    @cli.canonicalize_endpoint("http://localhost:3000/?token=x#frag"),
    content="http://localhost:3000",
  )
  inspect(
    @cli.canonicalize_endpoint("https://host/trac/project/"),
    content="https://host/trac/project",
  )
}

///|
test "every trailing slash is removed" {
  inspect(
    @cli.canonicalize_endpoint("http://localhost:3000//"),
    content="http://localhost:3000",
  )
  inspect(
    @cli.canonicalize_endpoint("http://example.com/trac///"),
    content="http://example.com/trac",
  )
}

///|
test "default ports and the scheme case are normalized" {
  inspect(
    @cli.canonicalize_endpoint("HTTPS://host:443/"),
    content="https://host",
  )
  inspect(
    @cli.canonicalize_endpoint("http://host:8080"),
    content="http://host:8080",
  )
}

///|
test "an unparseable endpoint is rejected" {
  for raw in ["not a url", "https://"] {
    try @cli.canonicalize_endpoint(raw) catch {
      @cli.Message(_) => ()
    } noraise {
      _ => fail("\{raw} was accepted")
    }
  }
}

///|
test "an endpoint with credentials is rejected without echoing them" {
  try @cli.canonicalize_endpoint("https://user:pw@t.example.com") catch {
    e =>
      inspect(
        e,
        content="credentials in the endpoint URL are not supported; pass the username with --username and enter the password at the prompt",
      )
  } noraise {
    _ => fail("credentials were accepted")
  }
}

///|
test "an endpoint serve cannot use is rejected" {
  for raw in ["ftp://t.example.com", "file:///etc/passwd", "ws://host"] {
    try @cli.canonicalize_endpoint(raw) catch {
      @cli.Message(_) => ()
    } noraise {
      _ => fail("\{raw} was accepted")
    }
  }
}

///|
test "an accepted endpoint is accepted by the SDK" {
  for
    raw in [
      "https://T.Example.com/", "http://localhost:3000/?token=x#frag", "https://host/trac/project/",
      "HTTPS://host:443/", "http://host:8080",
    ] {
    let canonical = @cli.canonicalize_endpoint(raw)
    ignore(@trac.new(endpoint=canonical, username="alice", password="pw"))
  }
}
