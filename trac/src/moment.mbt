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
