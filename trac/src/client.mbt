///|
/// A client for one Trac project, logged in as one user.
/// The fields are private so that nothing outside this package can read the credentials.
pub struct Trac {
  priv endpoint : Endpoint
  priv authorization : String
}

///|
/// Creates a client for the Trac project at `endpoint`, e.g. `https://example.com/trac/project`,
/// that logs in with HTTP Basic authentication.
///
/// # Raises
/// `Transport` when `endpoint` is not an http(s) URL, without echoing it;
/// `InvalidArgument` when `username` contains `:`, which Basic authentication cannot carry.
///
/// ```mbt check
/// test {
///   let trac = @trac.new(
///     endpoint="https://trac.example.com/project",
///     username="alice",
///     password="...",
///   )
///   ignore(trac)
///   try
///     @trac.new(
///       endpoint="ftp://trac.example.com",
///       username="alice",
///       password="...",
///     )
///   catch {
///     Transport(..) => ()
///     error => fail(error.to_json().stringify())
///   } noraise {
///     _ => fail("an endpoint that is not http(s) must be rejected")
///   }
/// }
/// ```
pub fn new(
  endpoint~ : String,
  username~ : String,
  password~ : String,
) -> Trac raise TracError {
  guard Endpoint::parse(endpoint) is Some(endpoint) else {
    raise Transport(message="endpoint must be http(s)://host[:port][/path]")
  }
  guard !username.contains(":") else {
    raise InvalidArgument(message="the username must not contain `:`")
  }
  let token = @base64.encode(@utf8.encode("\{username}:\{password}"))
  { endpoint, authorization: "Basic \{token}", }
}

///|
/// Low-level escape hatch for RPC methods the typed functions do not cover.
/// Calls `rpc_method` with `params` and returns its result, with datetimes as ISO 8601 text.
///
/// # Raises
/// `Fault` when Trac reports an error, `Http` when the answer's status is not 200,
/// `Decode` when the answer is not a JSON-RPC reply, and `Transport` on any other failure.
pub async fn call(
  trac : Trac,
  rpc_method : String,
  params : Array[Json],
) -> Json raise TracError {
  let (status, text) = trac.exchange(envelope(rpc_method, params)) catch {
    error => raise Transport(message="\{error}")
  }
  interpret(status, text)
}

///|
async fn Trac::exchange(self : Trac, body : Json) -> (Int32, String) {
  let client = @http.Client(self.endpoint.origin, headers={
    "Authorization": self.authorization,
    "Accept": "application/json",
  })
  defer client.close()
  let data = @utf8.encode(body.stringify())
  client.request(Post, self.endpoint.rpc_target(), extra_headers={
    "Content-Type": "application/json",
    "Content-Length": data.length().to_string(),
  })
  client.write(data)
  let response = client.end_request()
  (response.code, client.read_all().text())
}
