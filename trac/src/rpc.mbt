///|
/// `id` defaults to a fixed 1 because each call opens its own connection and reads exactly one reply.
fn envelope(rpc_method : String, params : Array[Json], id~ : Json = 1) -> Json {
  { "method": Json(rpc_method), "params": Json::array(params), "id": id }
}

///|
/// The result or the fault a reply object holds, or `None` when it holds neither.
/// It does not raise for an unknown shape, because a single call and a batch entry report one differently.
fn outcome_of(reply : Json) -> Result[Json, TracError]? {
  match reply {
    {
      "error": { "code": Number(code, ..), "message": String(message), .. },
      ..
    } => Some(Err(Fault(code=code.to_int(), message~)))
    { "error": Null, "result": result, .. } => Some(Ok(result))
    _ => None
  }
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
  match outcome_of(reply) {
    Some(Ok(result)) => from_wire(result)
    Some(Err(fault)) => raise fault
    None => raise Decode(message=NOT_JSON_RPC)
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
/// Wraps `bytes` as the binary value TracXMLRPC expects in a parameter, such as an attachment's content.
pub fn binary(bytes : BytesView) -> Json {
  { "__jsonclass__": ["binary", Json(@base64.encode(bytes))] }
}

///|
/// The bytes of a binary value in a result, or `None` when `json` is not one.
/// `call` leaves binary values as they came, so that a body is never mistaken for text.
/// Line breaks inside the base64 text are skipped, because Python's older encoders wrap it.
pub fn bytes_of(json : Json) -> Bytes? {
  guard json is { "__jsonclass__": [String("binary"), String(text)], .. } else {
    return None
  }
  Some(@base64.decode(text, ignore_whitespace=true)) catch {
    _ => None
  }
}

///|
/// The `Decode` failure of a result whose shape the typed functions do not know,
/// for the resource packages to report it the same way.
pub fn unexpected(rpc_method : String) -> TracError {
  Decode(
    message="Trac answered `\{rpc_method}` in a shape this client does not know",
  )
}

///|
/// The strings of a result that `rpc_method` answers as a list of text, in Trac's order.
///
/// # Raises
/// `Decode` as `unexpected` reports it when `json` is not an array of strings.
pub fn strings_of(
  rpc_method : String,
  json : Json,
) -> Array[String] raise TracError {
  guard json is Array(items) else { raise unexpected(rpc_method) }
  items.map(item => {
    guard item is String(text) else { raise unexpected(rpc_method) }
    text
  })
}
