///|
/// What a model receives from one `tools/call`, with the text parsed, since every tool answers JSON.
struct Called {
  payload : Json
  is_error : Bool
}

///|
/// The responses `server` writes, one per line, after an `initialize` followed by `requests`.
async fn exchange(server : @mcp.Server, requests : Array[Json]) -> Array[Json] {
  let (in_read, in_write) = @io.pipe()
  let (out_read, out_write) = @io.pipe()
  let output = @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      defer out_write.close()
      server.serve(in_read, out_write)
    })
    let collected = group.spawn(async fn() { out_read.read_all().text() })
    {
      defer in_write.close()
      let initialize : Json = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": { "protocolVersion": "2025-11-25", "capabilities": {} },
      }
      in_write.write(initialize.stringify() + "\n")
      for request in requests {
        in_write.write(request.stringify() + "\n")
      }
    }
    collected.wait()
  })
  let responses = []
  for line in output.split("\n") {
    if line.length() > 0 {
      responses.push(@json.parse(line.to_owned()))
    }
  }
  responses
}

///|
/// Calls the tool `name` through a whole MCP session with `server`, so that the arguments go through the same schema validation a model's call does.
async fn call(server : @mcp.Server, name : String, arguments : Json) -> Called {
  let responses = exchange(server, [
    {
      "jsonrpc": "2.0",
      "id": 2,
      "method": "tools/call",
      "params": { "name": name, "arguments": arguments },
    },
  ])
  guard responses
    is [
      _,
      {
        "result": {
          "content": [{ "text": String(text), .. }, ..],
          "isError": is_error,
          ..
        },
        ..
      },
      ..,
    ] else {
    fail("unexpected responses \{Json::array(responses).stringify()}")
  }
  { payload: @json.parse(text), is_error: is_error is True, }
}

///|
/// Like `call`, failing the test when the tool answers an error.
async fn succeed(server : @mcp.Server, name : String, arguments : Json) -> Json {
  let called = call(server, name, arguments)
  guard !called.is_error else {
    fail("\{name} failed: \{called.payload.stringify()}")
  }
  called.payload
}

///|
/// The full server acting as the administrator.
fn full() -> @mcp.Server raise {
  @cli.build_server(@livetest.admin(), false)
}
