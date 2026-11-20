///|
priv enum SearchAction {
  Search(String, Array[String]?)
  Filters
}

///|
fn search_input() -> @schema.Schema[SearchAction] {
  let query = @schema.required(
    "query",
    @schema.not_blank().describe(
      "Words to search for, as typed into the Trac search box.",
    ),
  )
  let filters = @schema.optional(
    "filters",
    @schema.array(@schema.not_blank(), min_items=1).describe(
      "Search only these filters, by the `name` that `filters` answers, such as `ticket`, `wiki` or `milestone`; every filter when left out.",
    ),
  )
  @schema.keyed([
    (
      "search",
      @schema.record([query.as_member(), filters.as_member()], v => {
        SearchAction::Search(v.get(query), v.get(filters))
      }),
    ),
    ("filters", @schema.record([], _ => SearchAction::Filters)),
  ])
}

///|
/// `trac_search`: full-text search across the Trac project.
/// It has no write actions, so it takes no mode.
pub fn search_tool(port : &SearchPort) -> @mcp.Tool {
  @mcp.tool(
    name="trac_search",
    description=describe_tool([
      "Full-text search across the Trac project's tickets, wiki pages, milestones, changesets and whatever else its search filters cover.",
      "`search` answers each match's `href`, `title`, `date`, `author` and `excerpt`; `filters` answers the filter names `search` takes.",
    ]),
    input=search_input(),
    handler=async fn(action) {
      match action {
        Search(query, filters) => respond(() => port.search(query, filters?))
        Filters => respond(() => port.search_filters())
      }
    },
  )
}
