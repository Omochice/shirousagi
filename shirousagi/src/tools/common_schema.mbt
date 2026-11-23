///|
/// Trac numbers tickets from 1.
fn ticket_id() -> @schema.Schema[Int32] {
  @schema.integer(min=1).describe(
    "Ticket number, as in `#123` or the URL path `/ticket/123`.",
  )
}

///|
/// An object whose values are all strings, under any keys.
/// `@schema.record` cannot express it because Trac fields are named by the
/// project's configuration, custom fields included, rather than known here.
fn string_map() -> @schema.Schema[Map[String, String]] {
  {
    json: () => {
      "type": "object",
      "additionalProperties": { "type": "string" },
    },
    decode: (input, path) => {
      guard input is Object(fields) else {
        raise @schema.Invalid(path~, message="expected an object")
      }
      let values : Map[String, String] = Map([])
      let errors : Array[@schema.SchemaError] = []
      for key, value in fields {
        match value {
          String(text) => values[key] = text
          _ =>
            errors.push(
              @schema.Invalid(path=[..path, key], message="expected a string"),
            )
        }
      }
      match errors {
        [] => values
        [error] => raise error
        _ => raise @schema.Many(errors)
      }
    },
  }
}
