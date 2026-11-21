///|
/// The fields a create or update writes; a field left `None` is not sent.
pub(all) struct Changes {
  /// Renames the component; only `update` sends it.
  name : String?
  /// The user new tickets of the component are assigned to.
  owner : String?
  description : String?
}

///|
/// Changes that write nothing until fields are set.
pub fn Changes::new(
  name? : String,
  owner? : String,
  description? : String,
) -> Changes {
  { name, owner, description, }
}

///|
fn Changes::to_wire(self : Changes) -> Json {
  let fields : Map[String, Json] = Map([])
  if self.name is Some(name) {
    fields["name"] = Json(name)
  }
  if self.owner is Some(owner) {
    fields["owner"] = Json(owner)
  }
  if self.description is Some(description) {
    fields["description"] = Json(description)
  }
  Json::object(fields)
}

///|
/// The names of every component.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn names(trac : @trac.Trac) -> Array[String] raise @trac.TracError {
  let json = trac |> @trac.call("ticket.component.getAll", [])
  guard json is Array(names) else {
    raise @trac.unexpected("ticket.component.getAll")
  }
  names.map(name => {
    guard name is String(name) else {
      raise @trac.unexpected("ticket.component.getAll")
    }
    name
  })
}

///|
/// The component `name` with its `owner` and `description`.
///
/// # Raises
/// `Fault` with code 404 when there is no such component, otherwise as `@trac.call` does.
pub async fn get(
  trac : @trac.Trac,
  name : String,
) -> Json raise @trac.TracError {
  let json = trac |> @trac.call("ticket.component.get", [Json(name)])
  guard json is Object(_) else {
    raise @trac.unexpected("ticket.component.get")
  }
  json
}

///|
/// Creates component `name` with `changes`, whose `name` is ignored.
///
/// # Raises
/// `Fault` when the component exists or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn create(
  trac : @trac.Trac,
  name : String,
  changes : Changes,
) -> Unit raise @trac.TracError {
  let changes = { ..changes, name: None, }
  ignore(
    trac
    |> @trac.call("ticket.component.create", [Json(name), changes.to_wire()]),
  )
}

///|
/// Applies `changes` to component `name`.
///
/// # Raises
/// `Fault` when there is no such component or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn update(
  trac : @trac.Trac,
  name : String,
  changes : Changes,
) -> Unit raise @trac.TracError {
  ignore(
    trac
    |> @trac.call("ticket.component.update", [Json(name), changes.to_wire()]),
  )
}

///|
/// Deletes component `name`.
///
/// # Raises
/// `Fault` when there is no such component or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  name : String,
) -> Unit raise @trac.TracError {
  ignore(trac |> @trac.call("ticket.component.delete", [Json(name)]))
}
