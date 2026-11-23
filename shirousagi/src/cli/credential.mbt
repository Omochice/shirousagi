///|
/// An endpoint paired with the login stored for it.
pub(all) struct Credential {
  /// The canonical endpoint, which is also the keyring account.
  endpoint : String
  /// The Trac user to log in as.
  username : String
  /// The password of `username`.
  password : String
}

///|
/// The keyring secret holding `username` and `password`.
/// The keyring stores one secret per account and Trac needs two values, so
/// they travel as JSON text, whose escaping keeps any character of either,
/// NUL included.
fn encode_secret(username~ : String, password~ : String) -> String {
  let secret : Json = { "username": Json(username), "password": Json(password) }
  secret.stringify()
}

///|
/// The username and password held by `secret`, or `None` when it is not the
/// shape `encode_secret` writes.
/// The parser's message is dropped because it may quote part of the password.
fn decode_secret(secret : String) -> (String, String)? {
  let json = @json.parse(secret) catch { _ => return None }
  guard json
    is Object(
      { "username": String(username), "password": String(password), .. } as fields
    ) &&
    fields.length() == 2 &&
    username != "" &&
    password != "" else {
    return None
  }
  Some((username, password))
}
