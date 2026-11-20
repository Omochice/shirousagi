///|
priv enum WikiAction {
  List
  Get(String, Int32?)
  Info(String, Int32?)
  RecentChanges(String)
  Put(String, text~ : String, comment~ : String?)
  Delete(String, Int32?)
}

///|
fn page_name() -> @schema.Schema[String] {
  @schema.not_blank().describe(
    "Wiki page name as in the URL path `/wiki/<name>`, such as `WikiStart` or `Guide/Install`; percent-decode it when taken from a URL.",
  )
}

///|
fn wiki_input(mode : Mode) -> @schema.Schema[WikiAction] {
  let name = @schema.required("name", page_name())
  let version = @schema.optional(
    "version",
    @schema.integer(min=1).describe(
      "Page version number, as `info` answers it; the latest version when left out.",
    ),
  )
  let delete_version = @schema.optional(
    "version",
    @schema.integer(min=1).describe(
      "Delete only this version of the page; the whole page with its history when left out.",
    ),
  )
  let since = @schema.required(
    "since",
    iso_datetime().describe(
      "ISO 8601 datetime such as `2026-11-21T09:00:00Z`; text without an offset is read as UTC.",
    ),
  )
  let text = @schema.required(
    "text",
    @schema.string().describe(
      "The whole new content of the page in TracWiki markup; it replaces the current text.",
    ),
  )
  let comment = @schema.optional(
    "comment",
    @schema.string().describe("Change comment shown in the page history."),
  )
  let read = [
    ("list", @schema.record([], _ => WikiAction::List)),
    (
      "get",
      @schema.record([name.as_member(), version.as_member()], v => {
        WikiAction::Get(v.get(name), v.get(version))
      }),
    ),
    (
      "info",
      @schema.record([name.as_member(), version.as_member()], v => {
        WikiAction::Info(v.get(name), v.get(version))
      }),
    ),
    (
      "recent_changes",
      @schema.record([since.as_member()], v => {
        WikiAction::RecentChanges(v.get(since))
      }),
    ),
  ]
  let write = [
    (
      "put",
      @schema.record(
        [name.as_member(), text.as_member(), comment.as_member()],
        v => {
          WikiAction::Put(v.get(name), text=v.get(text), comment=v.get(comment))
        },
      ),
    ),
    (
      "delete",
      @schema.record([name.as_member(), delete_version.as_member()], v => {
        WikiAction::Delete(v.get(name), v.get(delete_version))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn wiki_description(mode : Mode) -> String {
  let reading = [
    "`list` answers every page name; `get` answers a page's TracWiki text and `info` its version, author, `lastModified` and comment.",
    "`recent_changes` answers the latest version of every page changed since a datetime.",
  ]
  let lines = match mode {
    Readonly => reading
    Full =>
      [
        ..reading, "`put` stores the whole text as a new version, creating the page when it does not exist.",
      ]
  }
  describe_crud_tool(
    "wiki pages",
    mode,
    full_verbs="List, read, write, and delete",
    lines~,
  )
}

///|
/// `trac_wiki`: the wiki pages of the Trac project.
/// `Readonly` mode leaves out put and delete.
pub fn wiki_tool(port : &WikiPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_wiki",
    description=wiki_description(mode),
    input=wiki_input(mode),
    handler=async fn(action) {
      match action {
        List => respond(() => port.wiki_page_names())
        Get(name, version) => respond(() => port.get_wiki_page(name, version?))
        Info(name, version) =>
          respond(() => port.wiki_page_info(name, version?))
        RecentChanges(since) => respond(() => port.recent_wiki_changes(since))
        Put(name, text~, comment~) =>
          respond_ok(() => port.put_wiki_page(name, text~, comment?))
        Delete(name, version) =>
          respond_ok(() => port.delete_wiki_page(name, version?))
      }
    },
  )
}
