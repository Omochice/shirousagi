///|
fn ticket_reply(rpc_method : String) -> Json {
  match rpc_method {
    "ticket.create" => 7
    _ => [7, "", "", { "_ts": "1" }]
  }
}

///|
async test "a ticket is created without notifying unless notify is set" {
  let requests = @stub.record(ticket_reply, trac => {
    ignore(@tickets.create(trac, summary="s", description="d"))
  })
  guard requests is [{ "params": [_, _, _, notify], .. }] else {
    fail(Json::array(requests).stringify())
  }
  assert_eq(notify, Json(false))
}

///|
async test "a ticket is updated without notifying unless notify is set" {
  let requests = @stub.record(ticket_reply, trac => {
    ignore(@tickets.update(trac, 7, ts="1"))
  })
  guard requests is [{ "params": [_, _, _, notify], .. }] else {
    fail(Json::array(requests).stringify())
  }
  assert_eq(notify, Json(false))
}
