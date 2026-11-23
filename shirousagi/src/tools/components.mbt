///|
priv enum ComponentAction {
  List
  Get(String)
  Create(String, @components.Changes)
  Update(String, @components.Changes)
  Delete(String)
}

///|
fn components_input(mode : Mode) -> @schema.Schema[ComponentAction] {
  let name = @schema.required(
    "name",
    resource_name(
      "Component name, as the ticket field `component` holds it, such as `component1`.",
    ),
  )
  let new_name = @schema.optional(
    "new_name",
    resource_name("New name for the component."),
  )
  let owner = @schema.optional(
    "owner",
    @schema.string().describe(
      "Username that new tickets of the component are assigned to; empty for nobody.",
    ),
  )
  let description = @schema.optional(
    "description",
    @schema.string().describe(
      "Description of the component in TracWiki markup.",
    ),
  )
  let read = [
    ("list", @schema.record([], _ => ComponentAction::List)),
    (
      "get",
      @schema.record([name.as_member()], v => ComponentAction::Get(v.get(name))),
    ),
  ]
  let write = [
    (
      "create",
      @schema.record(
        [name.as_member(), owner.as_member(), description.as_member()],
        v => {
          ComponentAction::Create(
            v.get(name),
            @components.Changes::new(
              owner?=v.get(owner),
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
          owner.as_member(),
          description.as_member(),
        ],
        v => {
          ComponentAction::Update(
            v.get(name),
            @components.Changes::new(
              name?=v.get(new_name),
              owner?=v.get(owner),
              description?=v.get(description),
            ),
          )
        },
      ),
    ),
    (
      "delete",
      @schema.record([name.as_member()], v => {
        ComponentAction::Delete(v.get(name))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn components_description(mode : Mode) -> String {
  let reading = "`list` answers every component name; `get` answers a component's `owner` and `description`."
  let lines = match mode {
    Readonly => [reading]
    Full =>
      [
        reading, "`update` changes only the fields it is given; the writes need `TICKET_ADMIN`.",
      ]
  }
  describe_crud_tool("ticket components", mode, lines~)
}

///|
/// `trac_components`: the ticket components of the Trac project.
/// `Readonly` mode leaves out create, update, and delete.
pub fn components_tool(port : &ComponentPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_components",
    description=components_description(mode),
    input=components_input(mode),
    handler=async fn(action) {
      match action {
        List => respond(() => port.component_names())
        Get(name) => respond(() => port.get_component(name))
        Create(name, changes) =>
          respond_ok(() => port.create_component(name, changes))
        Update(name, changes) =>
          respond_ok(() => port.update_component(name, changes))
        Delete(name) => respond_ok(() => port.delete_component(name))
      }
    },
  )
}
