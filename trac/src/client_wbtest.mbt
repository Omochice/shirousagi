///|
test "an endpoint splits into origin and base path" {
  let plain = Endpoint::parse("http://localhost:8000").unwrap()
  inspect(plain.origin, content="http://localhost:8000")
  inspect(plain.rpc_target(), content="/login/rpc")
  let nested = Endpoint::parse("HTTPS://example.com/trac/project/").unwrap()
  inspect(nested.origin, content="https://example.com")
  inspect(nested.rpc_target(), content="/trac/project/login/rpc")
}

///|
test "unusable endpoints are rejected" {
  for
    endpoint in [
      "ftp://example.com", "example.com", "http://", "https:///trac", "https://user:pass@example.com",
      "https://example.com?x=1", "https://example.com/trac#top",
    ] {
    assert_true(Endpoint::parse(endpoint) is None, msg=endpoint)
  }
}

///|
test "the credentials become one Basic authorization header" {
  let trac = new(
    endpoint="http://localhost:8000",
    username="admin",
    password="admin-password",
  )
  inspect(trac.authorization, content="Basic YWRtaW46YWRtaW4tcGFzc3dvcmQ=")
}

///|
test "a username with a colon is refused because Basic authentication splits on it" {
  try
    new(endpoint="http://localhost:8000", username="a:b", password="p")
  catch {
    InvalidArgument(..) => ()
    error => fail("\{error}")
  } noraise {
    _ => fail("a username with `:` was accepted")
  }
}
