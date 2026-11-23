///|
priv enum EnumAction {
  List(@enums.Kind)
  Get(@enums.Kind, String)
  Statuses
  Create(@enums.Kind, String, value~ : String)
  Update(@enums.Kind, String, value~ : String)
  Delete(@enums.Kind, String)
}

///|
fn enums_input(mode : Mode) -> @schema.Schema[EnumAction] {
  let kind = @schema.required(
    "kind",
    @schema.choice([
      ("type", @enums.Kind::Type),
      ("resolution", Resolution),
      ("priority", Priority),
      ("severity", Severity),
    ]).describe("Which ticket field's list of allowed values to use."),
  )
  let name = @schema.required(
    "name",
    @schema.not_blank().describe(
      "Entry name, as the ticket field holds it, such as `defect` or `major`.",
    ),
  )
  let value = @schema.required(
    "value",
    @schema.not_blank().describe(
      "The entry's value, the text Trac sorts the list by, such as `3`.",
    ),
  )
  let read = [
    (
      "list",
      @schema.record([kind.as_member()], v => EnumAction::List(v.get(kind))),
    ),
    (
      "get",
      @schema.record([kind.as_member(), name.as_member()], v => {
        EnumAction::Get(v.get(kind), v.get(name))
      }),
    ),
    ("statuses", @schema.record([], _ => EnumAction::Statuses)),
  ]
  let write = [
    (
      "create",
      @schema.record([kind.as_member(), name.as_member(), value.as_member()], v => {
        EnumAction::Create(v.get(kind), v.get(name), value=v.get(value))
      }),
    ),
    (
      "update",
      @schema.record([kind.as_member(), name.as_member(), value.as_member()], v => {
        EnumAction::Update(v.get(kind), v.get(name), value=v.get(value))
      }),
    ),
    (
      "delete",
      @schema.record([kind.as_member(), name.as_member()], v => {
        EnumAction::Delete(v.get(kind), v.get(name))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn enums_description(mode : Mode) -> String {
  let reading = [
    "`kind` picks the ticket field: `type`, `resolution`, `priority` or `severity`.",
    "`list` answers the names of the kind in Trac's order; `get` answers an entry's `name` and `value`, the text Trac sorts by.",
    "`statuses` answers every ticket status the workflow defines; they are read only, because the workflow configuration, not a list, defines them.",
  ]
  let lines = match mode {
    Readonly => reading
    Full =>
      [
        ..reading, "`update` sets an entry's value; the writes need `TICKET_ADMIN`.",
      ]
  }
  describe_crud_tool(
    "ticket types, resolutions, priorities, severities, and statuses",
    mode,
    lines~,
  )
}

///|
/// `trac_enums`: the lists of allowed values of the ticket fields `type`,
/// `resolution`, `priority` and `severity`, and the ticket statuses.
/// `Readonly` mode leaves out create, update, and delete.
pub fn enums_tool(port : &EnumPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_enums",
    description=enums_description(mode),
    input=enums_input(mode),
    handler=async fn(action) {
      match action {
        List(kind) => respond(() => port.enum_names(kind))
        Get(kind, name) =>
          respond(() => {
            let value = port.get_enum(kind, name)
            { "name": Json(name), "value": Json(value) }
          })
        Statuses => respond(() => port.ticket_statuses())
        Create(kind, name, value~) =>
          respond_ok(() => port.create_enum(kind, name, value~))
        Update(kind, name, value~) =>
          respond_ok(() => port.update_enum(kind, name, value~))
        Delete(kind, name) => respond_ok(() => port.delete_enum(kind, name))
      }
    },
  )
}
