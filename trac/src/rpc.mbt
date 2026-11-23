///|
/// The id is fixed because each call opens its own connection and reads exactly one reply.
fn envelope(rpc_method : String, params : Array[Json]) -> Json {
  { "method": Json(rpc_method), "params": Json::array(params), "id": 1 }
}

///|
/// Names the likely cause, because a proxy or single sign-on gateway in front of Trac answers
/// with an HTML page, and a Trac without TracXMLRPC answers `/login/rpc` with its 404 page.
const NOT_JSON_RPC : String = "The server answered, but not with a JSON-RPC reply: the endpoint may point at something other than a Trac project, or the TracXMLRPC plugin may be missing or disabled"

///|
/// TracXMLRPC reports every fault with status 200, so the status only tells a
/// failure in front of the plugin, such as a rejected login, apart from one inside it.
fn interpret(status : Int32, text : String) -> Json raise TracError {
  guard status == 200 else { raise Http(status~) }
  // The parser's message is dropped because it quotes a character of the body, and no part of the body may reach the error.
  let reply = @json.parse(text) catch {
    _ => raise Decode(message=NOT_JSON_RPC)
  }
  match reply {
    {
      "error": { "code": Number(code, ..), "message": String(message), .. },
      ..
    } => raise Fault(code=code.to_int(), message~)
    { "error": Null, "result": result, .. } => from_wire(result)
    _ => raise Decode(message=NOT_JSON_RPC)
  }
}

///|
/// Replaces TracXMLRPC's `{"__jsonclass__": ["datetime", ...]}` with its ISO 8601 text,
/// so that callers handle plain JSON only.
/// Trac sends UTC without an offset, so `Z` is added to keep the text unambiguous.
fn from_wire(json : Json) -> Json {
  match json {
    { "__jsonclass__": [String("datetime"), String(text)], .. } =>
      Json(if text.has_suffix("Z") { text } else { text + "Z" })
    Array(items) => Json::array(items.map(from_wire))
    Object(fields) => {
      let converted : Map[String, Json] = Map([])
      for key, value in fields {
        converted[key] = from_wire(value)
      }
      Json::object(converted)
    }
    other => other
  }
}

///|
/// Wraps ISO 8601 text, with or without an offset, as the datetime value
/// TracXMLRPC expects in a parameter; text without an offset is read as UTC.
pub fn datetime(iso : String) -> Json {
  { "__jsonclass__": ["datetime", Json(iso)] }
}

///|
/// The `Decode` failure of a result whose shape the typed functions do not know,
/// for the resource packages to report it the same way.
pub fn unexpected(rpc_method : String) -> TracError {
  Decode(
    message="Trac answered `\{rpc_method}` in a shape this client does not know",
  )
}
