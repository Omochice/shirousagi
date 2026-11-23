///|
async test "shirousagi_info lists the RPC methods with their help and signatures" {
  let server = @cli.build_server(@livetest.admin(), true)
  guard succeed(server, "shirousagi_info", { "methods": {} }) is Array(methods) else {
    fail("methods did not answer an array")
  }
  assert_true(methods.contains(Json("ticket.get")))
  guard succeed(server, "shirousagi_info", {
      "method_help": { "name": "ticket.get" },
    })
    is String(help) else {
    fail("method_help did not answer text")
  }
  assert_true(help.has_prefix("array ticket.get(int id)"), msg=help)
  inspect(
    succeed(server, "shirousagi_info", {
      "method_signature": { "name": "ticket.get" },
    }).stringify(),
    content=(
      #|["array,int"]
    ),
  )
  inspect(
    succeed(server, "shirousagi_info", { "wiki_rpc_version": {} }).stringify(),
    content=(
      #|{"wiki_rpc_version":2}
    ),
  )
  let unknown = call(server, "shirousagi_info", {
    "method_help": { "name": "no.such" },
  })
  assert_true(unknown.is_error)
  assert_true(
    unknown.payload.stringify().contains("no.such"),
    msg=unknown.payload.stringify(),
  )
}
