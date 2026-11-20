///|
async test "the search filters include tickets and the wiki" {
  let filters = @livetest.admin() |> @search.filters()
  assert_true(filters.any(filter => filter is { "name": "ticket", .. }))
  assert_true(filters.any(filter => filter is { "name": "wiki", .. }))
}

///|
async test "a search limited to tickets finds a new ticket by its summary" {
  let trac = @livetest.admin()
  let word = @livetest.unique("needle")
  let id = trac |> @tickets.create(summary="find the \{word}", description="")
  defer @livetest.cleanup(() => trac |> @tickets.delete(id))
  let results = trac |> @search.perform(word, filters=["ticket"])
  assert_true(
    results.any(result => {
      result is { "href": String(href), .. } && href.has_suffix("/ticket/\{id}")
    }),
    msg=Json::array(results).stringify(),
  )
  assert_true(
    (trac |> @search.perform(word, filters=["wiki"])).is_empty(),
    msg="a wiki-only search found the ticket",
  )
}
