///|
async fn sent_replace(target : @attachments.Target) -> Json {
  let requests = @stub.record(_ => "a.bin", trac => {
    ignore(@attachments.put(trac, target, "a.bin", b"x"))
  })
  guard requests is [{ "params": [_, _, _, _, replace], .. }] else {
    fail(Json::array(requests).stringify())
  }
  replace
}

///|
async test "a ticket attachment is put without replacing unless replace is set" {
  assert_eq(sent_replace(Ticket(7)), Json(false))
}

///|
async test "a wiki attachment is put without replacing unless replace is set" {
  assert_eq(sent_replace(Wiki("Guide")), Json(false))
}
