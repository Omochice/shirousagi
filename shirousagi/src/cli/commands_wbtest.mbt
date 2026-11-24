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
fn accept(_trac : @trac.Trac) -> Unit {
  ()
}

///|
fn reject(_trac : @trac.Trac) -> Unit raise @trac.TracError {
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
async test "login stores nothing and names the account when Trac rejects the credential" {
  let store = fake([])
  try
    run_login(
      "https://T.example.com/",
      username="alice",
      store,
      fn() { "pw" },
      reject,
    )
  catch {
    e =>
      inspect(
        e,
        content="could not log in to https://t.example.com: HTTP 401: the username or password was rejected",
      )
  } noraise {
    _ => fail("a rejected credential was stored")
  }
  assert_true(store.entries.is_empty())
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
