///|
/// The fields a create or update writes; a field left `None` is not sent.
pub(all) struct Changes {
  /// Renames the version; only `update` sends it.
  name : String?
  /// When the version was or will be released.
  time : @trac.Moment?
  description : String?
}

///|
/// Changes that write nothing until fields are set.
pub fn Changes::new(
  name? : String,
  time? : @trac.Moment,
  description? : String,
) -> Changes {
  { name, time, description, }
}

///|
fn Changes::to_wire(self : Changes) -> Json {
  let fields : Map[String, Json] = Map([])
  if self.name is Some(name) {
    fields["name"] = Json(name)
  }
  if self.time is Some(time) {
    fields["time"] = time.to_wire()
  }
  if self.description is Some(description) {
    fields["description"] = Json(description)
  }
  Json::object(fields)
}

///|
/// The names of every version.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn names(trac : @trac.Trac) -> Array[String] raise @trac.TracError {
  let json = trac |> @trac.call("ticket.version.getAll", [])
  @trac.strings_of("ticket.version.getAll", json)
}

///|
/// The version `name` with its `time`, `null` when unset, and its `description`.
///
/// # Raises
/// `Fault` with code 404 when there is no such version, otherwise as `@trac.call` does.
pub async fn get(
  trac : @trac.Trac,
  name : String,
) -> Json raise @trac.TracError {
  let json = trac |> @trac.call("ticket.version.get", [Json(name)])
  @trac.unset_dates_as_null("ticket.version.get", json, ["time"])
}

///|
/// Creates version `name` with `changes`, whose `name` is ignored.
///
/// # Raises
/// `Fault` when the version exists or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn create(
  trac : @trac.Trac,
  name : String,
  changes : Changes,
) -> Unit raise @trac.TracError {
  let changes = { ..changes, name: None, }
  ignore(
    trac |> @trac.call("ticket.version.create", [Json(name), changes.to_wire()]),
  )
}

///|
/// Applies `changes` to version `name`.
///
/// # Raises
/// `Fault` when there is no such version or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn update(
  trac : @trac.Trac,
  name : String,
  changes : Changes,
) -> Unit raise @trac.TracError {
  ignore(
    trac |> @trac.call("ticket.version.update", [Json(name), changes.to_wire()]),
  )
}

///|
/// Deletes version `name`.
///
/// # Raises
/// `Fault` when there is no such version or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  name : String,
) -> Unit raise @trac.TracError {
  ignore(trac |> @trac.call("ticket.version.delete", [Json(name)]))
}
