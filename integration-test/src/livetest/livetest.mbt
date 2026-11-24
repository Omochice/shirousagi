///|
/// It fails rather than skips when a variable is unset, because a test that returns early counts as passed and would hide that nothing reached Trac.
fn variable(name : String) -> String raise {
  guard @env.get_env_var(name) is Some(value) else {
    fail("\{name} is unset; run `task test:integration`")
  }
  value
}

///|
/// The project URL of the Trac named by `SHIROUSAGI_TEST_ENDPOINT`.
pub fn endpoint() -> String raise {
  variable("SHIROUSAGI_TEST_ENDPOINT")
}

///|
/// The username of the test Trac's administrator, from `SHIROUSAGI_TEST_ADMIN_USER`.
pub fn admin_username() -> String raise {
  variable("SHIROUSAGI_TEST_ADMIN_USER")
}

///|
/// The password of the test Trac's administrator, from `SHIROUSAGI_TEST_ADMIN_PASSWORD`.
pub fn admin_password() -> String raise {
  variable("SHIROUSAGI_TEST_ADMIN_PASSWORD")
}

///|
/// A client for the test Trac acting as the administrator named by `SHIROUSAGI_TEST_ADMIN_USER`.
pub fn admin() -> @trac.Trac raise {
  @trac.new(
    endpoint=endpoint(),
    username=admin_username(),
    password=admin_password(),
  )
}

///|
/// A client for the same Trac acting as the viewer named by `SHIROUSAGI_TEST_VIEWER_USER`, who may read but not edit.
/// A refused write never happens to an administrator.
pub fn viewer() -> @trac.Trac raise {
  @trac.new(
    endpoint=endpoint(),
    username=variable("SHIROUSAGI_TEST_VIEWER_USER"),
    password=variable("SHIROUSAGI_TEST_VIEWER_PASSWORD"),
  )
}

///|
/// A name no earlier run used, so that tests sharing one Trac never meet each other's leftovers.
pub fn unique(prefix : String) -> String {
  "\{prefix}\{@async.now()}"
}

///|
/// Removes what a test created in Trac, from the test's `defer`.
/// Gives up after ten seconds and swallows errors,
/// so the cleanup can neither hang the test nor hide its assertion failure.
pub async fn cleanup(f : async () -> Unit) -> Unit noraise + nocancel {
  @async.protect_from_cancel(() => @async.with_timeout(cleanup_timeout_ms, f)) catch {
    _ => ()
  }
}

///|
let cleanup_timeout_ms = 10_000
