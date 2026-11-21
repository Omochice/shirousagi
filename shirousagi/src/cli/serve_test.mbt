///|
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
/// Each tool's actions as `tools/list` advertises them, for `read_only`.
/// The client is never asked to call Trac, so its endpoint is never dialed.
async fn advertised_actions(read_only : Bool) -> Map[String, Array[String]] {
  let trac = @trac.new(
    endpoint="http://localhost:8000/unused",
    username="alice",
    password="unused",
  )
  let responses = exchange(@cli.build_server(trac, read_only), [
    { "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {} },
  ])
  guard responses[1] is { "result": { "tools": Array(tools), .. }, .. } else {
    fail("no tools/list result")
  }
  let advertised = Map([])
  for tool in tools {
    guard tool
      is {
        "name": String(name),
        "inputSchema": { "properties": Object(actions), .. },
        ..
      } else {
      fail("a tool without a keyed schema: \{tool.stringify()}")
    }
    advertised[name] = actions.keys().collect()
  }
  advertised
}

///|
async test "the server lists every tool with all its actions" {
  @debug.debug_inspect(
    advertised_actions(false),
    content=(
      #|{
      #|  "trac_tickets": [
      #|    "query",
      #|    "get",
      #|    "changelog",
      #|    "actions",
      #|    "fields",
      #|    "recent_changes",
      #|    "create",
      #|    "update",
      #|    "delete",
      #|  ],
      #|  "trac_wiki": ["list", "get", "info", "recent_changes", "put", "delete"],
      #|  "trac_milestones": ["list", "get", "create", "update", "delete"],
      #|  "trac_components": ["list", "get", "create", "update", "delete"],
      #|  "trac_versions": ["list", "get", "create", "update", "delete"],
      #|  "trac_attachments": ["list", "get", "put", "delete"],
      #|  "trac_search": ["search", "filters"],
      #|  "shirousagi_info": ["show", "ping"],
      #|}
    ),
  )
}

///|
async test "readonly mode lists every tool without its write actions" {
  @debug.debug_inspect(
    advertised_actions(true),
    content=(
      #|{
      #|  "trac_tickets": ["query", "get", "changelog", "actions", "fields", "recent_changes"],
      #|  "trac_wiki": ["list", "get", "info", "recent_changes"],
      #|  "trac_milestones": ["list", "get"],
      #|  "trac_components": ["list", "get"],
      #|  "trac_versions": ["list", "get"],
      #|  "trac_attachments": ["list", "get"],
      #|  "trac_search": ["search", "filters"],
      #|  "shirousagi_info": ["show", "ping"],
      #|}
    ),
  )
}
