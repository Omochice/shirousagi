///|
/// The fields a create or update writes; a field left `None` is not sent.
pub(all) struct Changes {
  /// Renames the milestone; only `update` sends it.
  name : String?
  due : @trac.Moment?
  completed : @trac.Moment?
  description : String?
}

///|
/// Changes that write nothing until fields are set.
pub fn Changes::new(
  name? : String,
  due? : @trac.Moment,
  completed? : @trac.Moment,
  description? : String,
) -> Changes {
  { name, due, completed, description, }
}

///|
fn Changes::to_wire(self : Changes) -> Json {
  let fields : Map[String, Json] = Map([])
  if self.name is Some(name) {
    fields["name"] = Json(name)
  }
  if self.due is Some(due) {
    fields["due"] = due.to_wire()
  }
  if self.completed is Some(completed) {
    fields["completed"] = completed.to_wire()
  }
  if self.description is Some(description) {
    fields["description"] = Json(description)
  }
  Json::object(fields)
}

///|
/// The names of every milestone.
pub async fn names(trac : @trac.Trac) -> Array[String] raise @trac.TracError {
  let json = trac |> @trac.call("ticket.milestone.getAll", [])
  guard json is Array(names) else {
    raise @trac.unexpected("ticket.milestone.getAll")
  }
  names.map(name => {
    guard name is String(name) else {
      raise @trac.unexpected("ticket.milestone.getAll")
    }
    name
  })
}

///|
/// The milestone `name` with its `due` and `completed` dates, each `null` when unset.
///
/// # Raises
/// `Fault` when there is no such milestone, otherwise as `@trac.call` does.
pub async fn get(
  trac : @trac.Trac,
  name : String,
) -> Json raise @trac.TracError {
  let json = trac |> @trac.call("ticket.milestone.get", [Json(name)])
  guard json is Object(fields) else {
    raise @trac.unexpected("ticket.milestone.get")
  }
  let milestone : Map[String, Json] = Map([])
  for key, value in fields {
    // Trac answers 0 for an unset date, which a reader would take for the epoch.
    milestone[key] = match (key, value) {
      ("due" | "completed", Number(0, ..)) => Json::null()
      _ => value
    }
  }
  Json::object(milestone)
}

///|
/// Creates milestone `name` with `changes`, whose `name` is ignored.
///
/// # Raises
/// `Fault` when the milestone exists or the user lacks `MILESTONE_CREATE`, otherwise as `@trac.call` does.
pub async fn create(
  trac : @trac.Trac,
  name : String,
  changes : Changes,
) -> Unit raise @trac.TracError {
  let changes = { ..changes, name: None, }
  ignore(
    trac
    |> @trac.call("ticket.milestone.create", [Json(name), changes.to_wire()]),
  )
}

///|
/// Applies `changes` to milestone `name`.
///
/// # Raises
/// `Fault` when there is no such milestone or the user lacks `MILESTONE_MODIFY`, otherwise as `@trac.call` does.
pub async fn update(
  trac : @trac.Trac,
  name : String,
  changes : Changes,
) -> Unit raise @trac.TracError {
  ignore(
    trac
    |> @trac.call("ticket.milestone.update", [Json(name), changes.to_wire()]),
  )
}

///|
/// Deletes milestone `name`; its tickets keep no milestone.
///
/// # Raises
/// `Fault` when there is no such milestone or the user lacks `MILESTONE_DELETE`, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  name : String,
) -> Unit raise @trac.TracError {
  ignore(trac |> @trac.call("ticket.milestone.delete", [Json(name)]))
}
