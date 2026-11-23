///|
/// The ids of the tickets matching `query`, written in TracQuery syntax such as
/// `status!=closed&owner=alice&max=0`.
/// Trac pages the result by its own default unless `query` sets `max` and `page`.
pub async fn query(
  trac : @trac.Trac,
  query : String,
) -> Array[Int32] raise @trac.TracError {
  let json = trac |> @trac.call("ticket.query", [Json(query)])
  guard json is Array(ids) else { raise @trac.unexpected("ticket.query") }
  ids.map(id_of)
}

///|
/// The ticket `id` as one object: its fields, `id`, and the `_ts` token `update` checks.
///
/// # Raises
/// `Fault` with code 404 when there is no such ticket, otherwise as `@trac.call` does.
pub async fn get(trac : @trac.Trac, id : Int32) -> Json raise @trac.TracError {
  ticket_of("ticket.get", trac |> @trac.call("ticket.get", [Json(id)]))
}

///|
/// Creates a ticket and returns its id.
/// `fields` sets any other field by its name, such as `type`, `owner` or a custom field.
pub async fn create(
  trac : @trac.Trac,
  summary~ : String,
  description~ : String,
  fields~ : Map[String, Json] = Map([]),
  notify~ : Bool = false,
) -> Int32 raise @trac.TracError {
  let json = trac
    |> @trac.call("ticket.create", [
      Json(summary),
      Json(description),
      Json::object(fields),
      Json(notify),
    ])
  guard json is Number(id, ..) else { raise @trac.unexpected("ticket.create") }
  id.to_int()
}

///|
/// Applies the workflow `action` and `fields` to ticket `id` with `comment`, and returns the
/// updated ticket as `get` does.
/// `ts` is the `_ts` of the ticket the change was based on; Trac refuses the update when the
/// ticket changed since.
/// Without it the current `_ts` is read first, so the update cannot be refused as stale but
/// may overwrite a change made since the caller last looked.
///
/// # Raises
/// `Fault` when Trac refuses the change, such as a stale `ts` or an action that is not available,
/// otherwise as `@trac.call` does.
pub async fn update(
  trac : @trac.Trac,
  id : Int32,
  comment~ : String = "",
  action~ : String = "leave",
  fields~ : Map[String, Json] = Map([]),
  ts? : String,
  notify~ : Bool = false,
) -> Json raise @trac.TracError {
  let ts = match ts {
    Some(ts) => ts
    None => {
      guard get(trac, id) is { "_ts": String(ts), .. } else {
        raise @trac.unexpected("ticket.get")
      }
      ts
    }
  }
  let attributes : Map[String, Json] = Map([])
  for key, value in fields {
    attributes[key] = value
  }
  attributes["action"] = Json(action)
  attributes["_ts"] = Json(ts)
  let json = trac
    |> @trac.call("ticket.update", [
      Json(id),
      Json(comment),
      Json::object(attributes),
      Json(notify),
    ])
  ticket_of("ticket.update", json)
}

///|
/// Deletes ticket `id`.
///
/// # Raises
/// `Fault` when there is no such ticket or the user lacks `TICKET_ADMIN`, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  id : Int32,
) -> Unit raise @trac.TracError {
  ignore(trac |> @trac.call("ticket.delete", [Json(id)]))
}

///|
/// The changes made to ticket `id`, oldest first, one object per changed field.
/// A comment appears as the field `comment`, whose `oldvalue` is the comment number.
pub async fn changelog(
  trac : @trac.Trac,
  id : Int32,
) -> Array[Json] raise @trac.TracError {
  let json = trac |> @trac.call("ticket.changeLog", [Json(id)])
  guard json is Array(rows) else { raise @trac.unexpected("ticket.changeLog") }
  rows.map(change_of)
}

///|
/// The workflow actions the user may take on ticket `id`.
/// Each lists the `inputs` the action needs, by the field name `update` takes in `fields`.
pub async fn actions(
  trac : @trac.Trac,
  id : Int32,
) -> Array[Json] raise @trac.TracError {
  let json = trac |> @trac.call("ticket.getActions", [Json(id)])
  guard json is Array(rows) else { raise @trac.unexpected("ticket.getActions") }
  rows.map(action_of)
}

///|
/// The ticket fields of the project, with their types and, for a select, the allowed values.
pub async fn fields(trac : @trac.Trac) -> Json raise @trac.TracError {
  trac |> @trac.call("ticket.getTicketFields", [])
}

///|
fn id_of(json : Json) -> Int32 raise @trac.TracError {
  guard json is Number(id, ..) else { raise @trac.unexpected("ticket.query") }
  id.to_int()
}

///|
/// `ticket.get` and `ticket.update` answer `[id, created, changed, fields]`; the fields
/// already hold both times, so the ticket is the fields with the id added.
fn ticket_of(rpc_method : String, json : Json) -> Json raise @trac.TracError {
  guard json is Array([Number(_, ..) as id, _, _, Object(fields)]) else {
    raise @trac.unexpected(rpc_method)
  }
  let ticket : Map[String, Json] = { "id": id }
  for key, value in fields {
    ticket[key] = value
  }
  Json::object(ticket)
}

///|
fn change_of(row : Json) -> Json raise @trac.TracError {
  guard row is Array([time, author, field, oldvalue, newvalue, permanent]) else {
    raise @trac.unexpected("ticket.changeLog")
  }
  {
    "time": time,
    "author": author,
    "field": field,
    "oldvalue": oldvalue,
    "newvalue": newvalue,
    "permanent": permanent,
  }
}

///|
fn action_of(row : Json) -> Json raise @trac.TracError {
  guard row is Array([name, label, hints, Array(inputs)]) else {
    raise @trac.unexpected("ticket.getActions")
  }
  {
    "name": name,
    "label": label,
    "hints": hints,
    "inputs": Json::array(inputs.map(input_of)),
  }
}

///|
fn input_of(input : Json) -> Json raise @trac.TracError {
  guard input is Array([name, value, options]) else {
    raise @trac.unexpected("ticket.getActions")
  }
  { "name": name, "value": value, "options": options }
}
