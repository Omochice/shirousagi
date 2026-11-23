///|
test "the latest version of a page is read through the method itself" {
  let (rpc_method, params) = versioned("wiki.getPage", "WikiStart", None)
  inspect(rpc_method, content="wiki.getPage")
  inspect(
    Json::array(params).stringify(),
    content=(
      #|["WikiStart"]
    ),
  )
}

///|
test "an older version of a page is read through the Version method, with the version after the name" {
  let (rpc_method, params) = versioned("wiki.getPageHTML", "WikiStart", Some(3))
  inspect(rpc_method, content="wiki.getPageHTMLVersion")
  inspect(
    Json::array(params).stringify(),
    content=(
      #|["WikiStart",3]
    ),
  )
}
