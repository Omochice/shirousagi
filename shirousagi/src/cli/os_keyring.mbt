///|
/// The keyring service every shirousagi credential lives under; it differs from
/// redmoon's so the two servers never read each other's secrets.
pub const SERVICE : String = "shirousagi"

///|
/// The OS credential store, reached through `Omochice/keyring`.
pub struct OsKeyring {}

///|
/// The adapter for the credential store of the running OS.
pub fn OsKeyring::new() -> OsKeyring {
  OsKeyring::{ }
}

///|
/// macOS errSecInteractionNotAllowed: a keychain item is readable without a
/// prompt only by the executable that created it, so a rebuilt binary is
/// refused whenever no permission dialog can be shown (e.g. under `serve`).
const KEYCHAIN_INTERACTION_NOT_ALLOWED : Int32 = -25308

///|
fn refusal(code : Int32, account : String?) -> String {
  if code == @keyring.INTERNAL {
    return "the credential store could not be used; the keyring module itself failed, not the store"
  }
  if code != KEYCHAIN_INTERACTION_NOT_ALLOWED {
    return "the credential store refused the operation (code \{code})"
  }
  let (subject, endpoint) = match account {
    Some(account) => ("the password for \{account}", account)
    None => ("the stored passwords", "<endpoint>")
  }
  "the keychain did not let this shirousagi executable read \{subject}, which happens after shirousagi is rebuilt or upgraded; run `shirousagi logout --endpoint \{endpoint}` and then `shirousagi login --endpoint \{endpoint} --username <name>`"
}

///|
/// The keyring error is translated here rather than by the commands because
/// the CLI has no payload layer of its own where the tools do that work.
fn describe(error : @keyring.KeyringError, account : String?) -> CliError {
  match error {
    NoStore(message) => Message(message)
    Refused(code) => Message(refusal(code, account))
  }
}

///|
pub impl KeyringPort for OsKeyring with fn get(_, account~) {
  @keyring.get(service=SERVICE, account~) catch {
    error => raise describe(error, Some(account))
  }
}

///|
pub impl KeyringPort for OsKeyring with fn set(_, account~, secret~) {
  @keyring.set(service=SERVICE, account~, secret~) catch {
    error => raise describe(error, Some(account))
  }
}

///|
pub impl KeyringPort for OsKeyring with fn delete(_, account~) {
  @keyring.delete(service=SERVICE, account~) catch {
    error => raise describe(error, Some(account))
  }
}

///|
pub impl KeyringPort for OsKeyring with fn list(_) {
  @keyring.list(SERVICE) catch {
    error => raise describe(error, None)
  }
}

///|
pub extend OsKeyring with KeyringPort::{get, set, delete, list}
