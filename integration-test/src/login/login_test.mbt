///|
struct MemoryStore {
  entries : Map[String, String]
}

///|
impl @cli.KeyringPort for MemoryStore with fn get(self, account~) {
  self.entries.get(account)
}

///|
impl @cli.KeyringPort for MemoryStore with fn set(self, account~, secret~) {
  self.entries[account] = secret
}

///|
impl @cli.KeyringPort for MemoryStore with fn delete(self, account~) {
  self.entries.remove(account)
}

///|
impl @cli.KeyringPort for MemoryStore with fn list(self) {
  self.entries.keys().collect()
}

///|
fn empty_store() -> MemoryStore {
  { entries: {}, }
}

///|
async fn login(
  store : MemoryStore,
  endpoint : String,
  password : String,
) -> String {
  @cli.run_login(
    endpoint,
    username=@livetest.admin_username(),
    store,
    () => password,
    @cli.check_login,
  )
}

///|
async test "login stores the administrator's credential that Trac accepts" {
  let store = empty_store()
  let account = login(store, @livetest.endpoint(), @livetest.admin_password())
  let credential = @cli.resolve_credential(account, store)
  assert_eq(credential.username, @livetest.admin_username())
  assert_eq(credential.password, @livetest.admin_password())
}

///|
async test "login refuses a wrong password with Trac's answer and stores nothing" {
  let store = empty_store()
  try login(store, @livetest.endpoint(), "not-the-password") catch {
    error =>
      assert_true(
        error
        .to_string()
        .has_suffix(": HTTP 401: the username or password was rejected"),
        msg=error.to_string(),
      )
  } noraise {
    _ => fail("a wrong password was stored")
  }
  assert_true(store.entries.is_empty())
}

///|
async test "login refuses a URL that is not a Trac project and stores nothing" {
  let store = empty_store()
  let endpoint = "\{@livetest.endpoint()}/no-such-project"
  try login(store, endpoint, @livetest.admin_password()) catch {
    error =>
      assert_true(
        error.to_string().has_prefix("could not log in to \{endpoint}: "),
        msg=error.to_string(),
      )
  } noraise {
    _ => fail("a URL without Trac behind it was stored")
  }
  assert_true(store.entries.is_empty())
}
