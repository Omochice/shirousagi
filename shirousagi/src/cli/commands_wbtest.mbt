///|
struct FakeStore {
  entries : Map[String, String]
}

///|
impl KeyringPort for FakeStore with fn get(self, account~) {
  self.entries.get(account)
}

///|
impl KeyringPort for FakeStore with fn set(self, account~, secret~) {
  self.entries[account] = secret
}

///|
impl KeyringPort for FakeStore with fn delete(self, account~) {
  self.entries.remove(account)
}

///|
impl KeyringPort for FakeStore with fn list(self) {
  self.entries.keys().collect()
}

///|
fn fake(entries : Array[(String, String)]) -> FakeStore {
  { entries: Map::from_array(entries), }
}

///|
fn stored(username : String, password : String) -> String {
  encode_secret(username~, password~)
}

///|
let accept : async (@trac.Trac) -> Unit raise @trac.TracError = _ => ()

///|
let reject : async (@trac.Trac) -> Unit raise @trac.TracError = _ => {
  raise Http(status=401)
}

///|
async test "login checks the credential with Trac once, before storing it" {
  let store = fake([])
  let stored_when_checked = []
  ignore(
    run_login("https://t.example.com", username="alice", store, fn() { "pw" }, _ => {
      stored_when_checked.push(store.entries.length())
    }),
  )
  assert_eq(stored_when_checked, [0])
  assert_eq(
    store.entries.get("https://t.example.com").map(decode_secret),
    Some(Some(("alice", "pw"))),
  )
}

///|
/// What login of `alice` at `https://T.example.com/` fails with when Trac answers `error`, after checking that nothing was stored.
async fn login_failure(error : @trac.TracError) -> String {
  let store = fake([])
  let message = try
    run_login(
      "https://T.example.com/",
      username="alice",
      store,
      fn() { "pw" },
      _ => raise error,
    )
  catch {
    e => e.to_string()
  } noraise {
    _ => fail("a credential Trac refused was stored")
  }
  assert_true(store.entries.is_empty())
  message
}

///|
async test "a refused login names the account, with no hint for a failure that has none" {
  assert_eq(
    login_failure(Transport(message="connection refused")),
    "could not log in to https://t.example.com: connection refused",
  )
  assert_eq(
    login_failure(Decode(message="not a JSON-RPC reply")),
    "could not log in to https://t.example.com: not a JSON-RPC reply",
  )
  assert_eq(
    login_failure(Http(status=500)),
    "could not log in to https://t.example.com: HTTP 500",
  )
}

///|
async test "a refused login with HTTP 404 points at the URL and the TracXMLRPC plugin" {
  inspect(
    login_failure(Http(status=404)),
    content=(
      #|could not log in to https://t.example.com: HTTP 404
      #|Check that the URL is the Trac project and that the TracXMLRPC plugin is enabled there.
    ),
  )
}

///|
async test "a login refused for lacking XML_RPC asks for the permission" {
  inspect(
    login_failure(
      Fault(
        code=403,
        message="XML_RPC privileges are required to perform this operation. You don't have the required permissions.",
      ),
    ),
    content=(
      #|could not log in to https://t.example.com: Trac fault 403: XML_RPC privileges are required to perform this operation. You don't have the required permissions.
      #|Ask a Trac administrator to grant XML_RPC to alice.
    ),
  )
}

///|
async test "a login refused with HTTP 401 points at the password and Basic authentication" {
  inspect(
    login_failure(Http(status=401)),
    content=(
      #|could not log in to https://t.example.com: HTTP 401: the username or password was rejected
      #|Check the username and password, and that the web server accepts Basic authentication at https://t.example.com/login/rpc.
    ),
  )
}

///|
async test "a rejected login keeps the credential stored earlier" {
  let earlier = stored("alice", "pw")
  let store = fake([("https://t.example.com", earlier)])
  try
    run_login(
      "https://t.example.com",
      username="alice",
      store,
      fn() { "wrong" },
      reject,
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("a rejected credential was stored")
  }
  assert_eq(store.entries.get("https://t.example.com"), Some(earlier))
}

///|
async test "login does not ask Trac about a credential it refuses by itself" {
  for case in [("alice", ""), ("  ", "pw"), ("al:ice", "pw")] {
    let (username, input) = case
    let checked = []
    try
      run_login("https://t.example.com", username~, fake([]), fn() { input }, _ => {
        checked.push(())
      })
    catch {
      _ => ()
    } noraise {
      _ => fail("the login of `\{username}` was stored")
    }
    assert_true(checked.is_empty())
  }
}

///|
async test "login stores the username and password under the canonical account" {
  let store = fake([])
  let account = run_login(
    "https://T.example.com/project/",
    username="alice",
    store,
    fn() { " pass word \n" },
    accept,
  )
  inspect(account, content="https://t.example.com/project")
  assert_eq(
    store.entries.get("https://t.example.com/project").map(decode_secret),
    Some(Some(("alice", " pass word "))),
  )
}

///|
async test "login drops a CRLF or a lone CR line ending but nothing else" {
  for input in ["pw\r\n", "pw\r", "pw\n"] {
    let store = fake([])
    ignore(
      run_login(
        "https://t.example.com",
        username="alice",
        store,
        fn() { input },
        accept,
      ),
    )
    assert_eq(
      store.entries.get("https://t.example.com").map(decode_secret),
      Some(Some(("alice", "pw"))),
    )
  }
}

///|
async test "login keeps a line ending that is not the last one" {
  let store = fake([])
  ignore(
    run_login(
      "https://t.example.com",
      username="alice",
      store,
      fn() { "pw\n\n" },
      accept,
    ),
  )
  assert_eq(
    store.entries.get("https://t.example.com").map(decode_secret),
    Some(Some(("alice", "pw\n"))),
  )
}

///|
async test "login rejects an empty password" {
  for input in ["", "\n", "\r\n", "\r"] {
    let store = fake([])
    try
      run_login(
        "https://t.example.com",
        username="alice",
        store,
        fn() { input },
        accept,
      )
    catch {
      e => inspect(e, content="no password was provided")
    } noraise {
      _ => fail("an empty password was stored")
    }
    assert_true(store.entries.is_empty())
  }
}

///|
async test "login rejects a blank username before reading the password" {
  for username in ["", "  "] {
    let store = fake([])
    let read = []
    try
      run_login(
        "https://t.example.com",
        username~,
        store,
        fn() {
          read.push(())
          "pw"
        },
        accept,
      )
    catch {
      e => inspect(e, content="no username was provided")
    } noraise {
      _ => fail("a blank username was stored")
    }
    assert_true(read.is_empty())
    assert_true(store.entries.is_empty())
  }
}

///|
async test "login rejects a username Basic authentication cannot carry" {
  let store = fake([])
  let read = []
  try
    run_login(
      "https://t.example.com",
      username="al:ice",
      store,
      fn() {
        read.push(())
        "pw"
      },
      accept,
    )
  catch {
    e => inspect(e, content="the username must not contain `:`")
  } noraise {
    _ => fail("a username with `:` was stored")
  }
  assert_true(read.is_empty())
  assert_true(store.entries.is_empty())
}

///|
async test "login reports a failed secret read and stores nothing" {
  let store = fake([])
  try
    run_login(
      "https://t.example.com",
      username="alice",
      store,
      () => raise Message("stdin is not a terminal"),
      accept,
    )
  catch {
    e => inspect(e, content="stdin is not a terminal")
  } noraise {
    _ => fail("a failed secret read was stored")
  }
  assert_true(store.entries.is_empty())
}

///|
async test "login rejects credentials in the endpoint and stores nothing" {
  let store = fake([])
  try
    run_login(
      "https://user:pw@t.example.com",
      username="alice",
      store,
      fn() { "pw" },
      accept,
    )
  catch {
    e =>
      inspect(
        e,
        content="credentials in the endpoint URL are not supported; pass the username with --username and enter the password at the prompt",
      )
  } noraise {
    _ => fail("credentials were accepted")
  }
  assert_true(store.entries.is_empty())
}

///|
async test "login rejects a scheme the SDK cannot use and stores nothing" {
  let store = fake([])
  try
    run_login(
      "ftp://t.example.com",
      username="alice",
      store,
      fn() { "pw" },
      accept,
    )
  catch {
    e => inspect(e, content="invalid endpoint URL: ftp://t.example.com")
  } noraise {
    _ => fail("ftp was accepted")
  }
  assert_true(store.entries.is_empty())
}

///|
test "resolve returns the stored login for the canonical account" {
  let store = fake([("https://t.example.com", stored("alice", "pw"))])
  let credential = resolve_credential("https://t.example.com/", store)
  inspect(credential.endpoint, content="https://t.example.com")
  inspect(credential.username, content="alice")
  inspect(credential.password, content="pw")
}

///|
test "resolve tells the user to log in when nothing is stored" {
  try resolve_credential("https://t.example.com/", fake([])) catch {
    e =>
      inspect(
        e,
        content="no stored password for https://t.example.com; run `shirousagi login --endpoint https://t.example.com --username <name>` first",
      )
  } noraise {
    _ => fail("a missing credential was resolved")
  }
}

///|
test "resolve tells the user to log in again for an unreadable secret, without quoting it" {
  let store = fake([("https://t.example.com", "{\"password\":\"hunter2\"")])
  try resolve_credential("https://t.example.com", store) catch {
    e => {
      inspect(
        e,
        content="the stored credential for https://t.example.com is not one this shirousagi can read; run `shirousagi login --endpoint https://t.example.com --username <name>` again",
      )
      assert_false(e.to_string().contains("hunter2"))
    }
  } noraise {
    _ => fail("a malformed secret was resolved")
  }
}

///|
test "logout removes the stored credential" {
  let store = fake([("https://t.example.com", stored("alice", "pw"))])
  inspect(
    run_logout("https://t.example.com/", store),
    content="https://t.example.com",
  )
  assert_true(store.entries.is_empty())
}

///|
test "list shows the endpoints only, sorted, and is empty when nothing is stored" {
  let store = fake([
    ("https://b.example.com", stored("bob", "secret-b")),
    ("https://a.example.com", stored("alice", "secret-a")),
  ])
  @debug.debug_inspect(
    run_list(store),
    content="[\"https://a.example.com\", \"https://b.example.com\"]",
  )
  @debug.debug_inspect(run_list(fake([])), content="[]")
}

///|
async test "serve refuses to start without a stored credential" {
  try run_serve("https://t.example.com", false, fake([])) catch {
    e =>
      assert_true(
        e.to_string().has_prefix("no stored password for https://t.example.com"),
      )
  } noraise {
    _ => fail("serve started without a credential")
  }
}
