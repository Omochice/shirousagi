///|
priv enum TicketAction {
  Query(String)
  Get(Int32)
  Changelog(Int32)
  Actions(Int32)
  Fields
  RecentChanges(String)
  Create(
    summary~ : String,
    description~ : String,
    fields~ : Map[String, String]
  )
  Update(
    Int32,
    comment~ : String?,
    action~ : String?,
    fields~ : Map[String, String]?,
    ts~ : String?
  )
  Delete(Int32)
}

///|
/// Ticket fields to set by name, refusing the names that `arguments` already
/// set, because the SDK writes those over whatever `fields` holds.
fn ticket_fields_schema(
  reserved : Array[String],
  arguments : String,
) -> @schema.Schema[Map[String, String]] {
  string_map()
  .refine(
    fields => !reserved.iter().any(name => fields.contains(name)),
    "must not set \{reserved.map(name => "`\{name}`").join(" or ")}; \{arguments}",
  )
  .describe(
    "Other ticket fields to set, by the field name `fields` lists, such as `{\"type\": \"defect\", \"owner\": \"alice\", \"milestone\": \"1.0\"}`; every value is a string, `0` or `1` for a checkbox.",
  )
}

///|
fn tickets_input(mode : Mode) -> @schema.Schema[TicketAction] {
  let id = @schema.required("id", ticket_id())
  let query = @schema.required(
    "query",
    @schema.string().describe(
      "TracQuery string of `field=value` conditions joined by `&`, such as `status!=closed&owner=alice&max=0`; `~=` contains, `^=` starts with, `|` separates alternatives, and `order=<field>` sorts. Trac answers one page of its default size unless `max` is set, and `max=0` answers every match.",
    ),
  )
  let summary = @schema.required(
    "summary",
    @schema.not_blank().describe("One-line title of the ticket."),
  )
  let description = @schema.required(
    "description",
    @schema.string().describe("Body of the ticket in TracWiki markup."),
  )
  let create_fields = @schema.optional(
    "fields",
    ticket_fields_schema(
      ["summary", "description"],
      "pass them as `summary` and `description`",
    ),
  )
  let comment = @schema.optional(
    "comment",
    @schema.string().describe(
      "Comment in TracWiki markup added to the ticket's history.",
    ),
  )
  let action = @schema.optional(
    "action",
    @schema.not_blank().describe(
      "Workflow action to take, by the `name` that `actions` lists, such as `resolve` or `reassign`; `leave` (the default) keeps the status. Set the inputs the action lists in `fields`.",
    ),
  )
  let update_fields = @schema.optional(
    "fields",
    ticket_fields_schema(["action", "_ts"], "pass them as `action` and `ts`"),
  )
  let since = @schema.required(
    "since",
    iso_datetime().describe(
      "ISO 8601 datetime such as `2026-11-21T09:00:00Z`; text without an offset is read as UTC.",
    ),
  )
  let ts = @schema.optional(
    "ts",
    @schema.not_blank().describe(
      "The `_ts` of the ticket as `get` answered it. Trac then refuses the update when the ticket changed since, instead of overwriting that change; without it the update applies to whatever the ticket holds now.",
    ),
  )
  let read = [
    (
      "query",
      @schema.record([query.as_member()], v => TicketAction::Query(v.get(query))),
    ),
    ("get", @schema.record([id.as_member()], v => TicketAction::Get(v.get(id)))),
    (
      "changelog",
      @schema.record([id.as_member()], v => TicketAction::Changelog(v.get(id))),
    ),
    (
      "actions",
      @schema.record([id.as_member()], v => TicketAction::Actions(v.get(id))),
    ),
    ("fields", @schema.record([], _ => TicketAction::Fields)),
    (
      "recent_changes",
      @schema.record([since.as_member()], v => {
        TicketAction::RecentChanges(v.get(since))
      }),
    ),
  ]
  let write = [
    (
      "create",
      @schema.record(
        [
          summary.as_member(),
          description.as_member(),
          create_fields.as_member(),
        ],
        v => {
          TicketAction::Create(
            summary=v.get(summary),
            description=v.get(description),
            fields=v.get(create_fields).unwrap_or(Map([])),
          )
        },
      ),
    ),
    (
      "update",
      @schema.record(
        [
          id.as_member(),
          comment.as_member(),
          action.as_member(),
          update_fields.as_member(),
          ts.as_member(),
        ],
        v => {
          TicketAction::Update(
            v.get(id),
            comment=v.get(comment),
            action=v.get(action),
            fields=v.get(update_fields),
            ts=v.get(ts),
          )
        },
      ),
    ),
    (
      "delete",
      @schema.record([id.as_member()], v => TicketAction::Delete(v.get(id))),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn tickets_description(mode : Mode) -> String {
  let reading = [
    "`query` answers the ids of the matching tickets; `get` answers one ticket's fields with its `id` and its `_ts` change token.",
    "`changelog` answers a ticket's history oldest first, `fields` the project's ticket fields with their types and allowed values.",
    "`recent_changes` answers the ids of the tickets changed since a datetime.",
  ]
  let lines = match mode {
    Readonly =>
      [
        ..reading, "`actions` answers the workflow actions the user may take on a ticket.",
      ]
    Full =>
      [
        ..reading, "`update` changes a ticket through a workflow `action`; `actions` lists the actions the user may take on a ticket and the `inputs` each one needs, which `update` takes in `fields`.",
        "Pass the `_ts` from `get` as `ts` to `update`, so that Trac refuses a change based on a stale copy of the ticket.",
      ]
  }
  describe_crud_tool("tickets", mode, lines~)
}

///|
/// `trac_tickets`: the tickets of the Trac project.
/// `Readonly` mode leaves out create, update, and delete.
pub fn tickets_tool(port : &TicketPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_tickets",
    description=tickets_description(mode),
    input=tickets_input(mode),
    handler=async fn(action) {
      match action {
        Query(query) => respond(() => port.query_tickets(query))
        Get(id) => respond(() => port.get_ticket(id))
        Changelog(id) => respond(() => port.ticket_changelog(id))
        Actions(id) => respond(() => port.ticket_actions(id))
        Fields => respond(() => port.ticket_fields())
        RecentChanges(since) => respond(() => port.recent_ticket_changes(since))
        Create(summary~, description~, fields~) =>
          respond(() => {
            let id = port.create_ticket(summary~, description~, fields~)
            { "id": Json(id) }
          })
        Update(id, comment~, action~, fields~, ts~) =>
          respond(() => port.update_ticket(id, comment?, action?, fields?, ts?))
        Delete(id) => respond_ok(() => port.delete_ticket(id))
      }
    },
  )
}
