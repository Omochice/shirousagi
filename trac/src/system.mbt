///|
/// The TracXMLRPC API version as `[epoch, major, minor]`, which also proves the login works.
///
/// # Raises
/// `TracError` as `call` does.
pub async fn api_version(trac : Trac) -> Json raise TracError {
  trac |> call("system.getAPIVersion", [])
}
