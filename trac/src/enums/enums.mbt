///|
/// A ticket field whose allowed values a Trac administrator maintains as a list.
pub(all) enum Kind {
  Type
  Resolution
  Priority
  Severity
}

///|
/// The prefix of the RPC methods for the list of `self`.
fn Kind::methods(self : Kind) -> String {
  match self {
    Type => "ticket.type"
    Resolution => "ticket.resolution"
    Priority => "ticket.priority"
    Severity => "ticket.severity"
  }
}

///|
/// The names in the list of `kind`, in Trac's order.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn names(
  trac : @trac.Trac,
  kind : Kind,
) -> Array[String] raise @trac.TracError {
  let rpc_method = "\{kind.methods()}.getAll"
  @trac.strings_of(rpc_method, trac |> @trac.call(rpc_method, []))
}

///|
/// The value of entry `name` in the list of `kind`, the text Trac orders the list by, such as `"3"`.
///
/// # Raises
/// `Fault` with code 404 when there is no such entry, otherwise as `@trac.call` does.
pub async fn get(
  trac : @trac.Trac,
  kind : Kind,
  name : String,
) -> String raise @trac.TracError {
  let rpc_method = "\{kind.methods()}.get"
  let json = trac |> @trac.call(rpc_method, [Json(name)])
  guard json is String(value) else { raise @trac.unexpected(rpc_method) }
  value
}

///|
/// Adds entry `name` with `value` to the list of `kind`.
///
/// # Raises
/// `Fault` when the entry exists or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn create(
  trac : @trac.Trac,
  kind : Kind,
  name : String,
  value : String,
) -> Unit raise @trac.TracError {
  ignore(
    trac |> @trac.call("\{kind.methods()}.create", [Json(name), Json(value)]),
  )
}

///|
/// Sets the value of entry `name` in the list of `kind`.
///
/// # Raises
/// `Fault` when there is no such entry or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn update(
  trac : @trac.Trac,
  kind : Kind,
  name : String,
  value : String,
) -> Unit raise @trac.TracError {
  ignore(
    trac |> @trac.call("\{kind.methods()}.update", [Json(name), Json(value)]),
  )
}

///|
/// Removes entry `name` from the list of `kind`.
///
/// # Raises
/// `Fault` when there is no such entry or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  kind : Kind,
  name : String,
) -> Unit raise @trac.TracError {
  ignore(trac |> @trac.call("\{kind.methods()}.delete", [Json(name)]))
}

///|
/// Every ticket status the workflow knows.
/// The statuses come from the workflow configuration rather than a list, so they are only read.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn statuses(trac : @trac.Trac) -> Array[String] raise @trac.TracError {
  @trac.strings_of(
    "ticket.status.getAll",
    trac |> @trac.call("ticket.status.getAll", []),
  )
}
