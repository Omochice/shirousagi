///|
priv enum AttachmentAction {
  List(@attachments.Target)
  Get(@attachments.Target, String)
  Put(
    @attachments.Target,
    String,
    content~ : Bytes,
    description~ : String?,
    replace~ : Bool?
  )
  Delete(@attachments.Target, String)
}

///|
/// Base64 text decoded to the bytes it stands for.
/// It decodes in the schema rather than in the handler, so malformed text is
/// reported as invalid arguments with its path like any other value.
fn base64_bytes() -> @schema.Schema[Bytes] {
  {
    json: () => { "type": "string", "contentEncoding": "base64" },
    decode: (input, path) => {
      guard input is String(text) else {
        raise @schema.Invalid(path~, message="expected a string")
      }
      @base64.decode(text) catch {
        _ => raise @schema.Invalid(path~, message="must be base64 text")
      }
    },
  }
}

///|
/// An action on the attachments of exactly one ticket or wiki page.
/// The owner is two flat members rather than one nested object, so a model
/// names it the way the other tools name a ticket or a page.
fn on_target(
  members : Array[@schema.Member],
  build : (@schema.Values, @attachments.Target) -> AttachmentAction raise @schema.SchemaError,
) -> @schema.Schema[AttachmentAction] {
  let ticket = @schema.optional("ticket", ticket_id())
  let page = @schema.optional("page", page_name())
  @schema.record([ticket.as_member(), page.as_member(), ..members], v => {
    let target : @attachments.Target = match (v.get(ticket), v.get(page)) {
      (Some(id), None) => Ticket(id)
      (None, Some(name)) => Wiki(name)
      // require_one has already refused these before the record decodes.
      _ =>
        raise @schema.Invalid(
          path=[],
          message="pass exactly one of `ticket` and `page`",
        )
    }
    build(v, target)
  }).require_one([ticket.as_member(), page.as_member()])
}

///|
fn attachments_input(mode : Mode) -> @schema.Schema[AttachmentAction] {
  let filename = @schema.required(
    "filename",
    @schema.not_blank().describe("Attachment filename, as `list` answers it."),
  )
  let content = @schema.required(
    "content_base64",
    base64_bytes().describe("The whole content of the file, encoded as base64."),
  )
  let description = @schema.optional(
    "description",
    @schema.string().describe("Description shown next to the attachment."),
  )
  let replace = @schema.optional(
    "replace",
    @schema.boolean().describe(
      "Whether to overwrite an attachment of the same name; when `false` (the default), Trac keeps it and stores the new file under a numbered name such as `a.2.bin`.",
    ),
  )
  let read = [
    ("list", on_target([], (_, target) => AttachmentAction::List(target))),
    (
      "get",
      on_target([filename.as_member()], (v, target) => {
        AttachmentAction::Get(target, v.get(filename))
      }),
    ),
  ]
  let write = [
    (
      "put",
      on_target(
        [
          filename.as_member(),
          content.as_member(),
          description.as_member(),
          replace.as_member(),
        ],
        (v, target) => {
          AttachmentAction::Put(
            target,
            v.get(filename),
            content=v.get(content),
            description=v.get(description),
            replace=v.get(replace),
          )
        },
      ),
    ),
    (
      "delete",
      on_target([filename.as_member()], (v, target) => {
        AttachmentAction::Delete(target, v.get(filename))
      }),
    ),
  ]
  actions(mode, read~, write~)
}

///|
fn attachments_description(mode : Mode) -> String {
  let reading = [
    "Every action names the owner with exactly one of `ticket`, a ticket number, and `page`, a wiki page name.",
    "`list` answers a ticket's attachments as `{filename, description, size, time, author}`, but a wiki page's as `{filename}` only, because Trac reports the size and the rest for ticket attachments alone.",
    "`get` answers `{filename, content_base64}`, the file's content encoded as base64.",
  ]
  let lines = match mode {
    Readonly => reading
    Full =>
      [
        ..reading, "`put` stores base64 content and answers the `filename` Trac stored it under, which differs from the one given when an attachment of that name exists and `replace` is not set.",
      ]
  }
  describe_crud_tool(
    "attachments",
    mode,
    full_verbs="List, read, attach, and delete",
    lines~,
  )
}

///|
/// `trac_attachments`: the files attached to tickets and wiki pages.
/// `Readonly` mode leaves out put and delete.
pub fn attachments_tool(port : &AttachmentPort, mode : Mode) -> @mcp.Tool {
  @mcp.tool(
    name="trac_attachments",
    description=attachments_description(mode),
    input=attachments_input(mode),
    handler=async fn(action) {
      match action {
        List(target) => respond(() => port.attachments(target))
        Get(target, filename) =>
          respond(() => {
            let content = port.get_attachment(target, filename)
            {
              "filename": Json(filename),
              "content_base64": Json(@base64.encode(content)),
            }
          })
        Put(target, filename, content~, description~, replace~) =>
          respond(() => {
            let stored = port.put_attachment(
              target,
              filename,
              content,
              description?,
              replace?,
            )
            { "filename": Json(stored) }
          })
        Delete(target, filename) =>
          respond_ok(() => port.delete_attachment(target, filename))
      }
    },
  )
}
