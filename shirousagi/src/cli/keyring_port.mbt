///|
/// Where credentials are kept, addressed by canonical endpoint.
/// The secret is opaque here; `credential.mbt` gives it its shape.
pub(open) trait KeyringPort {
  /// The secret stored for `account`, or `None` when there is none.
  fn get(Self, account~ : String) -> String? raise CliError
  /// Stores `secret` for `account`, replacing any existing one.
  fn set(Self, account~ : String, secret~ : String) -> Unit raise CliError
  /// Removes the secret for `account`; an absent one is not an error.
  fn delete(Self, account~ : String) -> Unit raise CliError
  /// The accounts that hold a secret, in no particular order.
  fn list(Self) -> Array[String] raise CliError
}
