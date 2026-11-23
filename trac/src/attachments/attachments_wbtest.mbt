///|
test "a ticket attachment row becomes an object with every column named" {
  let row : Json = ["a.bin", "d", 3, "2026-11-21T05:24:44.291320Z", "admin"]
  inspect(
    ticket_attachment_of(row).stringify(),
    content=(
      #|{"filename":"a.bin","description":"d","size":3,"time":"2026-11-21T05:24:44.291320Z","author":"admin"}
    ),
  )
}

///|
test "a ticket attachment row of another length is an unknown shape" {
  try ticket_attachment_of(["a.bin", "d"]) catch {
    Decode(..) => ()
    error => fail("\{error}")
  } noraise {
    _ => fail("a short row was accepted")
  }
}

///|
test "a wiki attachment path loses exactly its page, slashes in the page included" {
  inspect(
    wiki_attachment_of("Guide/Install", "Guide/Install/p.txt").stringify(),
    content=(
      #|{"filename":"p.txt"}
    ),
  )
}

///|
test "a wiki attachment path under another page is an unknown shape" {
  for path in [Json("Other/p.txt"), Json("Guide/Installp.txt"), Json(1)] {
    try wiki_attachment_of("Guide/Install", path) catch {
      Decode(..) => ()
      error => fail("\{error}")
    } noraise {
      _ => fail("\{path.stringify()} was accepted")
    }
  }
}

///|
test "the wiki path joins page and filename with one slash" {
  inspect(path_of("WikiStart", "p.txt"), content="WikiStart/p.txt")
}

///|
test "a ticket attachment is read by the ticket id and the filename" {
  let (rpc_method, params) = addressed("get", Ticket(7), "a.bin")
  inspect(rpc_method, content="ticket.getAttachment")
  inspect(
    Json::array(params).stringify(),
    content=(
      #|[7,"a.bin"]
    ),
  )
}

///|
test "a ticket attachment is deleted by the ticket id and the filename" {
  let (rpc_method, params) = addressed("delete", Ticket(7), "a.bin")
  inspect(rpc_method, content="ticket.deleteAttachment")
  inspect(
    Json::array(params).stringify(),
    content=(
      #|[7,"a.bin"]
    ),
  )
}

///|
test "a wiki attachment is read by one path of the page and the filename" {
  let (rpc_method, params) = addressed("get", Wiki("Guide/Install"), "p.txt")
  inspect(rpc_method, content="wiki.getAttachment")
  inspect(
    Json::array(params).stringify(),
    content=(
      #|["Guide/Install/p.txt"]
    ),
  )
}

///|
test "a wiki attachment is deleted by one path of the page and the filename" {
  let (rpc_method, params) = addressed("delete", Wiki("Guide/Install"), "p.txt")
  inspect(rpc_method, content="wiki.deleteAttachment")
  inspect(
    Json::array(params).stringify(),
    content=(
      #|["Guide/Install/p.txt"]
    ),
  )
}
