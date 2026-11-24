///|
/// The password as read, without the line ending that ends the input.
/// Only that one line ending is dropped, because spaces at either end can be
/// part of a password.
/// A lone `\r` counts as one because the Windows console read stops at the
/// `\n` of its `\r\n` and hands over the `\r`.
fn strip_line_ending(input : String) -> String {
  let input = if input.has_suffix("\n") {
    input[:input.length() - 1].to_owned()
  } else {
    input
  }
  if input.has_suffix("\r") {
    input[:input.length() - 1].to_owned()
  } else {
    input
  }
}

///|
/// Stores `username` and the password read by `read_secret` for `endpoint`
/// once `check` succeeds with a client logged in as them, and returns the
/// account they were stored under.
/// The username is checked before the password is read, so that a user is
/// not asked for a password that cannot be stored.
///
/// # Raises
/// `Message` for an invalid endpoint, a username that is empty or that Trac
/// cannot log in with, a password that cannot be read or is empty, a failing
/// `check`, or a failing store.
pub async fn run_login(
  endpoint : String,
  username~ : String,
  store : &KeyringPort,
  read_secret : async () -> String,
  check : async (@trac.Trac) -> Unit raise @trac.TracError,
) -> String raise CliError {
  let account = canonicalize_endpoint(endpoint)
  if username.trim() == "" {
    raise Message("no username was provided")
  }
  ignore(@trac.new(endpoint=account, username~, password="")) catch {
    error => raise Message("\{error}")
  }
  let password = strip_line_ending(
    read_secret() catch {
      error => raise Message("\{error}")
    },
  )
  if password == "" {
    raise Message("no password was provided")
  }
  let trac = @trac.new(endpoint=account, username~, password~) catch {
    error => raise Message("\{error}")
  }
  check(trac) catch {
    error => {
      let failure = "could not log in to \{account}: \{error}"
      match login_hint(error, account~, username~) {
        Some(hint) => raise Message("\{failure}\n\{hint}")
        None => raise Message(failure)
      }
    }
  }
  store.set(account~, secret=encode_secret(username~, password~))
  account
}

///|
/// Succeeds when Trac accepts the login of `trac` for RPC.
///
/// # Raises
/// `TracError` when Trac refuses the login or cannot be reached.
pub async fn check_login(trac : @trac.Trac) -> Unit raise @trac.TracError {
  // The API version reads nothing from the project, so a check through it
  // refuses no user that holds `XML_RPC`.
  ignore(@trac.api_version(trac))
}

///|
/// Removes the stored credential for `endpoint` and returns its account.
///
/// # Raises
/// `Message` for an invalid endpoint or a failing store.
pub fn run_logout(
  endpoint : String,
  store : &KeyringPort,
) -> String raise CliError {
  let account = canonicalize_endpoint(endpoint)
  store.delete(account~)
  account
}

///|
/// Returns the endpoints that have a stored credential, sorted for stable
/// output.
///
/// # Raises
/// `Message` for a failing store.
pub fn run_list(store : &KeyringPort) -> Array[String] raise CliError {
  let endpoints = store.list()
  endpoints.sort()
  endpoints
}

///|
/// Looks up the username and password for `endpoint`.
///
/// # Raises
/// `Message` telling the user to run `shirousagi login` when no credential is
/// stored or the stored one is not readable.
pub fn resolve_credential(
  endpoint : String,
  store : &KeyringPort,
) -> Credential raise CliError {
  let account = canonicalize_endpoint(endpoint)
  let login = "shirousagi login --endpoint \{account} --username <name>"
  guard store.get(account~) is Some(secret) else {
    raise Message("no stored password for \{account}; run `\{login}` first")
  }
  guard decode_secret(secret) is Some((username, password)) else {
    raise Message(
      "the stored credential for \{account} is not one this shirousagi can read; run `\{login}` again",
    )
  }
  { endpoint: account, username, password, }
}

///|
/// Serves the MCP protocol on stdin and stdout for the Trac project at
/// `endpoint`.
/// Nothing else may write to stdout, because it is the protocol channel.
///
/// # Raises
/// `Message` when no readable credential is stored for `endpoint`, the client
/// cannot be built from it, or the server fails while serving.
pub async fn run_serve(
  endpoint : String,
  read_only : Bool,
  store : &KeyringPort,
) -> Unit raise CliError {
  let credential = resolve_credential(endpoint, store)
  let trac = @trac.new(
    endpoint=credential.endpoint,
    username=credential.username,
    password=credential.password,
  ) catch {
    error => raise Message("\{error}")
  }
  build_server(trac, read_only).serve_stdio() catch {
    error => raise Message("\{error}")
  }
}

///|
fn login_hint(
  error : @trac.TracError,
  account~ : String,
  username~ : String,
) -> String? {
  match error {
    Http(status=401) =>
      Some(
        "Check the username and password, and that the web server accepts Basic authentication at \{account}/login/rpc.",
      )
    // A URL that is no Trac project and a project without TracXMLRPC both
    // answer the same 404, so the hint has to name both.
    Http(status=404) =>
      Some(
        "Check that the URL is the Trac project and that the TracXMLRPC plugin is enabled there.",
      )
    Fault(code=403, ..) =>
      Some("Ask a Trac administrator to grant XML_RPC to \{username}.")
    _ => None
  }
}
