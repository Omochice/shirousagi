///|
/// Compact JSON, since a model reads the payload rather than a human.
fn[T : ToJson] success(value : T) -> @mcp.ToolResult {
  @mcp.ToolResult::text(value.to_json().stringify())
}

///|
/// The success of an operation with nothing to report.
fn success_ok() -> @mcp.ToolResult {
  @mcp.ToolResult::text("{\"ok\":true}")
}

///|
/// A failure holding `{"status": ..., "errors": [...]}`, the only failure
/// shape a model sees.
fn failure(status : Int32, errors : Array[String]) -> @mcp.ToolResult {
  let payload : Json = { "status": Json(status), "errors": Json(errors) }
  @mcp.ToolResult::error(payload.stringify())
}

///|
/// A failure that has neither a Trac fault code nor an HTTP status, such as
/// invalid arguments; the status is 0.
fn local_failure(errors : Array[String]) -> @mcp.ToolResult {
  failure(0, errors)
}

///|
/// Maps a Trac failure to the failure payload.
/// A fault keeps Trac's own code, since TracXMLRPC answers every fault with
/// HTTP 200 and the code is the only thing that tells a missing resource from
/// a refused permission.
/// An HTTP failure keeps its status and the error's own text, which explains a
/// rejected login; anything else reports status 0 with its message.
fn failure_of(error : @trac.TracError) -> @mcp.ToolResult {
  match error {
    Fault(code~, message~) => failure(code, [message])
    Http(status~) => failure(status, [error.to_string()])
    Decode(message~) | Transport(message~) | InvalidArgument(message~) =>
      local_failure([message])
  }
}

///|
/// Never raises: a failed `call` becomes the failure payload instead.
async fn[T : ToJson] respond(
  call : async () -> T raise @trac.TracError,
) -> @mcp.ToolResult {
  let value = call() catch { error => return failure_of(error) }
  success(value)
}

///|
/// Like `respond`, answering `{"ok":true}` for a call that returns nothing.
async fn respond_ok(
  call : async () -> Unit raise @trac.TracError,
) -> @mcp.ToolResult {
  call() catch {
    error => return failure_of(error)
  }
  success_ok()
}
