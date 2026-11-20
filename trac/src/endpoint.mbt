///|
/// The parsed form of the project URL a client talks to.
priv struct Endpoint {
  /// `scheme://host[:port]`
  origin : String
  /// Empty, or starts with `/` and has no trailing `/`.
  base_path : String
}

///|
/// Splits a project URL into its origin and base path.
/// Returns `None` for anything but `http(s)://host[:port][/path]`; the URL is
/// not echoed anywhere because it may carry credentials.
fn Endpoint::parse(endpoint : String) -> Endpoint? {
  guard endpoint.find("://") is Some(scheme_end) else { return None }
  let scheme = endpoint[:scheme_end].to_lower().to_owned()
  guard scheme == "http" || scheme == "https" else { return None }
  let rest = endpoint[scheme_end + 3:]
  let (authority, path) = match rest.find("/") {
    Some(slash) => (rest[:slash], rest[slash:])
    None => (rest, "")
  }
  guard authority != "" &&
    !authority.contains_any(chars="@?#") &&
    !path.contains_any(chars="?#") else {
    return None
  }
  Some({
    origin: "\{scheme}://\{authority}",
    base_path: path.trim_end(chars="/").to_owned(),
  })
}

///|
/// The request target of the authenticated RPC handler.
/// `/login/rpc` rather than `/rpc`, because only the former makes the web
/// server ask for credentials; `/rpc` runs every call as anonymous.
fn Endpoint::rpc_target(self : Endpoint) -> String {
  "\{self.base_path}/login/rpc"
}
