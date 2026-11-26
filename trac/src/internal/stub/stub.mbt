///|
/// Runs `scenario` against a stand-in Trac on a loopback port and returns the JSON-RPC requests it received, in the order they arrived.
/// The stand-in answers each request with the result `answer` gives for its method.
pub async fn record(
  answer : (String) -> Json,
  scenario : async (@trac.Trac) -> Unit,
) -> Array[Json] {
  @async.with_task_group(group => {
    // Port 0 lets the system pick a free port, so parallel tests never collide.
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let requests : Array[Json] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((_, body, conn) => {
        let request = @json.parse(body.read_all().text())
        requests.push(request)
        guard request is { "method": String(rpc_method), .. } else {
          fail("a request without a method: \{request.stringify()}")
        }
        let reply : Json = {
          "result": answer(rpc_method),
          "error": null,
          "id": 1,
        }
        conn.send_response(200, "OK", extra_headers={
          "Content-Type": "application/json",
        })
        conn.write(reply.stringify())
        conn.end_response()
      })
    })
    let trac = @trac.new(
      endpoint="http://127.0.0.1:\{server.addr.port()}",
      username="stub",
      password="stub",
    )
    scenario(trac)
    requests
  })
}
