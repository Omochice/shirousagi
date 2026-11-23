///|
priv enum MilestoneAction {
  List
  Get(String)
  Create(String, @milestones.Changes)
  Update(String, @milestones.Changes)
  Delete(String)
}

///|
fn milestones_input(mode : Mode) -> @schema.Schema[MilestoneAction] {
  let name = @schema.required(
    "name",
    resource_name("Milestone name, as in the URL path `/milestone/<name>`."),
  )
  let new_name = @schema.optional(
    "new_name",
    resource_name("New name for the milestone."),
  )
  let due_text = "When the milestone is due, as an ISO 8601 datetime such as `2026-12-31T00:00:00Z`; text without an offset is read as UTC."
  let completed_text = "When the milestone was completed, as an ISO 8601 datetime; setting it marks the milestone completed."
  let due = @schema.optional("due", moment(due_text))
  let completed = @schema.optional("completed", moment(completed_text))
  let update_due = @schema.optional(
    "due",
    clearable_moment("\{due_text} `null` clears the due date."),
  )
  let update_completed = @schema.optional(
    "completed",
    clearable_moment("\{completed_text} `null` reopens the milestone."),
  )
  let description = @schema.optional(
    "description",
    @schema.string().describe(
      "Description of the milestone in TracWiki markup.",
    ),
  )
  let read = [
    ("list", @schema.record([], _ => MilestoneAction::List)),
    (
      "get",
      @schema.record([name.as_member()], v => MilestoneAction::Get(v.get(name))),
    ),
  ]
  let write = [
    (
      "create",
      @schema.record(
        [
          name.as_member(),
          due.as_member(),
          completed.as_member(),
          description.as_member(),
        ],
        v => {
          MilestoneAction::Create(
            v.get(name),
            @milestones.Changes::new(
              due?=v.get(due),
              completed?=v.get(completed),
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
          update_due.as_member(),
          update_completed.as_member(),
          description.as_member(),
        ],
        v => {
          MilestoneAction::Update(
            v.get(name),
            @milestones.Changes::new(
              name?=v.get(new_name),
              due?=v.get(update_due),
              completed?=v.get(update_completed),
              description?=v.get(description),
            ),
          )
        },
      ),
    ),
    (
      "delete",
      @schema.record([name.as_member()], v => {
        MilestoneAction::Delete(v.get(name))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn milestones_description(mode : Mode) -> String {
  let reading = "`list` answers every milestone name; `get` answers a milestone's `due` and `completed` datetimes, each `null` when unset, and its description."
  let lines = match mode {
    Readonly => [reading]
    Full =>
      [
        reading, "`update` changes only the fields it is given; `null` for `due` or `completed` clears that date.",
      ]
  }
  describe_crud_tool("milestones", mode, lines~)
}

///|
/// `trac_milestones`: the milestones of the Trac project.
/// `Readonly` mode leaves out create, update, and delete.
pub fn milestones_tool(port : &MilestonePort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_milestones",
    description=milestones_description(mode),
    input=milestones_input(mode),
    handler=async fn(action) {
      match action {
        List => respond(() => port.milestone_names())
        Get(name) => respond(() => port.get_milestone(name))
        Create(name, changes) =>
          respond_ok(() => port.create_milestone(name, changes))
        Update(name, changes) =>
          respond_ok(() => port.update_milestone(name, changes))
        Delete(name) => respond_ok(() => port.delete_milestone(name))
      }
    },
  )
}
