///|
/// The TracXMLRPC API version as `[epoch, major, minor]`, which also proves the login works.
///
/// # Raises
/// `TracError` as `call` does.
pub async fn api_version(trac : Trac) -> Json raise TracError {
  trac |> call("system.getAPIVersion", [])
}

///|
/// The names of every RPC method the user may call, such as `ticket.get`.
///
/// # Raises
/// `TracError` as `call` does.
pub async fn methods(trac : Trac) -> Array[String] raise TracError {
  strings_of("system.listMethods", trac |> call("system.listMethods", []))
}

///|
/// The documentation of RPC method `name`, its signature line first.
///
/// # Raises
/// `Fault` when there is no such method, otherwise as `call` does.
pub async fn method_help(trac : Trac, name : String) -> String raise TracError {
  let json = trac |> call("system.methodHelp", [Json(name)])
  guard json is String(help) else { raise unexpected("system.methodHelp") }
  help
}

///|
/// The signatures of RPC method `name`, one per way to call it, each the return type and then the
/// parameter types joined by commas, such as `"array,int"`.
///
/// # Raises
/// `Fault` when there is no such method, otherwise as `call` does.
pub async fn method_signature(
  trac : Trac,
  name : String,
) -> Array[String] raise TracError {
  strings_of(
    "system.methodSignature",
    trac |> call("system.methodSignature", [Json(name)]),
  )
}
