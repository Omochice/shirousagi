///|
priv enum VersionAction {
  List
  Get(String)
  Create(String, @versions.Changes)
  Update(String, @versions.Changes)
  Delete(String)
}

///|
fn versions_input(mode : Mode) -> @schema.Schema[VersionAction] {
  let name = @schema.required(
    "name",
    resource_name(
      "Version name, as the ticket field `version` holds it, such as `1.0`.",
    ),
  )
  let new_name = @schema.optional(
    "new_name",
    resource_name("New name for the version."),
  )
  let time_text = "When the version was or will be released, as an \{iso_datetime_hint}"
  let time = @schema.optional("time", moment(time_text))
  let update_time = @schema.optional(
    "time",
    clearable_moment("\{time_text} `null` clears it."),
  )
  let description = @schema.optional(
    "description",
    @schema.string().describe("Description of the version in TracWiki markup."),
  )
  let read = [
    ("list", @schema.record([], _ => VersionAction::List)),
    (
      "get",
      @schema.record([name.as_member()], v => VersionAction::Get(v.get(name))),
    ),
  ]
  let write = [
    (
      "create",
      @schema.record(
        [name.as_member(), time.as_member(), description.as_member()],
        v => {
          VersionAction::Create(
            v.get(name),
            @versions.Changes::new(
              time?=v.get(time),
              description?=v.get(description),
            ),
          )
        },
      ),
    ),
    (
      "update",
      @schema.record(
        [
          name.as_member(),
          new_name.as_member(),
          update_time.as_member(),
          description.as_member(),
        ],
        v => {
          VersionAction::Update(
            v.get(name),
            @versions.Changes::new(
              name?=v.get(new_name),
              time?=v.get(update_time),
              description?=v.get(description),
            ),
          )
        },
      ),
    ),
    (
      "delete",
      @schema.record([name.as_member()], v => VersionAction::Delete(v.get(name))),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn versions_description(mode : Mode) -> String {
  let reading = "`list` answers every version name; `get` answers a version's release `time`, `null` when unset, and its description."
  let lines = match mode {
    Readonly => [reading]
    Full =>
      [
        reading, "`update` changes only the fields it is given; `null` for `time` clears it. The writes need `TICKET_ADMIN`.",
      ]
  }
  describe_crud_tool("ticket versions", mode, lines~)
}

///|
/// `trac_versions`: the ticket versions of the Trac project.
/// `Readonly` mode leaves out create, update, and delete.
pub fn versions_tool(port : &VersionPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_versions",
    description=versions_description(mode),
    input=versions_input(mode),
    handler=async fn(action) {
      match action {
        List => respond(() => port.version_names())
        Get(name) => respond(() => port.get_version(name))
        Create(name, changes) =>
          respond_ok(() => port.create_version(name, changes))
        Update(name, changes) =>
          respond_ok(() => port.update_version(name, changes))
        Delete(name) => respond_ok(() => port.delete_version(name))
      }
    },
  )
}
