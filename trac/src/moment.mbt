///|
/// A date to set on a milestone or a version, or `Unset` to clear it.
pub(all) enum Moment {
  /// ISO 8601 text, read as UTC when it has no offset.
  At(String)
  Unset
}

///|
/// The parameter value of the date.
/// TracXMLRPC reads `0` as "no date", the same value it answers for an unset one.
pub fn Moment::to_wire(self : Moment) -> Json {
  match self {
    At(iso) => datetime(iso)
    Unset => Json(0)
  }
}

///|
/// The object `rpc_method` answered, with each unset date among `dates` shown as `null`.
/// Trac answers 0 for an unset date, which a reader would take for the epoch.
///
/// # Raises
/// `Decode` as `unexpected` reports it when `json` is not an object.
pub fn unset_dates_as_null(
  rpc_method : String,
  json : Json,
  dates : Array[String],
) -> Json raise TracError {
  guard json is Object(fields) else { raise unexpected(rpc_method) }
  let object : Map[String, Json] = Map([])
  for key, value in fields {
    object[key] = match value {
      Number(0, ..) if dates.contains(key) => Json::null()
      _ => value
    }
  }
  Json::object(object)
}
