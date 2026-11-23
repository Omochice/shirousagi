///|
/// The ticket or wiki page an attachment belongs to.
pub(all) enum Target {
  /// The ticket with this number.
  Ticket(Int32)
  /// The wiki page with this name, such as `WikiStart` or `Guide/Install`.
  Wiki(String)
}

///|
/// The attachments of `target`, each as `{filename, description, size, time, author}` for a ticket
/// and as `{filename}` alone for a wiki page, because TracXMLRPC answers only the paths of a page's attachments.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn list(
  trac : @trac.Trac,
  target : Target,
) -> Array[Json] raise @trac.TracError {
  match target {
    Ticket(id) => {
      let json = trac |> @trac.call("ticket.listAttachments", [Json(id)])
      guard json is Array(rows) else {
        raise @trac.unexpected("ticket.listAttachments")
      }
      rows.map(ticket_attachment_of)
    }
    Wiki(page) => {
      let json = trac |> @trac.call("wiki.listAttachments", [Json(page)])
      guard json is Array(paths) else {
        raise @trac.unexpected("wiki.listAttachments")
      }
      paths.map(path => wiki_attachment_of(page, path))
    }
  }
}

///|
/// The content of attachment `filename` of `target`.
///
/// # Raises
/// `Fault` with code 404 when there is no such attachment, otherwise as `@trac.call` does.
pub async fn get(
  trac : @trac.Trac,
  target : Target,
  filename : String,
) -> Bytes raise @trac.TracError {
  let (rpc_method, json) = match target {
    Ticket(id) =>
      (
        "ticket.getAttachment",
        trac |> @trac.call("ticket.getAttachment", [Json(id), Json(filename)]),
      )
    Wiki(page) =>
      (
        "wiki.getAttachment",
        trac
        |> @trac.call("wiki.getAttachment", [Json(path_of(page, filename))]),
      )
  }
  guard @trac.bytes_of(json) is Some(bytes) else {
    raise @trac.unexpected(rpc_method)
  }
  bytes
}

///|
/// Stores `content` as attachment `filename` of `target` and returns the filename Trac stored it under.
/// Unless `replace` is set, Trac keeps an existing attachment of the same name and stores the new one
/// under a numbered name, such as `a.2.bin` for `a.bin`.
///
/// # Raises
/// `Fault` when there is no such ticket or page or the user may not attach to it, otherwise as `@trac.call` does.
pub async fn put(
  trac : @trac.Trac,
  target : Target,
  filename : String,
  content : BytesView,
  description~ : String = "",
  replace~ : Bool = false,
) -> String raise @trac.TracError {
  let (rpc_method, owner) = match target {
    Ticket(id) => ("ticket.putAttachment", Json(id))
    // putAttachmentEx rather than putAttachment, because only it takes a description and `replace`.
    Wiki(page) => ("wiki.putAttachmentEx", Json(page))
  }
  let json = trac
    |> @trac.call(rpc_method, [
      owner,
      Json(filename),
      Json(description),
      @trac.binary(content),
      Json(replace),
    ])
  guard json is String(stored) else { raise @trac.unexpected(rpc_method) }
  stored
}

///|
/// Deletes attachment `filename` of `target`.
///
/// # Raises
/// `Fault` when there is no such attachment or the user may not delete it, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  target : Target,
  filename : String,
) -> Unit raise @trac.TracError {
  let (rpc_method, json) = match target {
    Ticket(id) =>
      (
        "ticket.deleteAttachment",
        trac
        |> @trac.call("ticket.deleteAttachment", [Json(id), Json(filename)]),
      )
    Wiki(page) =>
      (
        "wiki.deleteAttachment",
        trac
        |> @trac.call("wiki.deleteAttachment", [Json(path_of(page, filename))]),
      )
  }
  guard json is True else { raise @trac.unexpected(rpc_method) }
}

///|
/// The wiki methods other than putAttachmentEx name an attachment by one path, the page and the filename joined by `/`.
fn path_of(page : String, filename : String) -> String {
  "\{page}/\{filename}"
}

///|
fn ticket_attachment_of(row : Json) -> Json raise @trac.TracError {
  guard row is Array([filename, description, size, time, author]) else {
    raise @trac.unexpected("ticket.listAttachments")
  }
  {
    "filename": filename,
    "description": description,
    "size": size,
    "time": time,
    "author": author,
  }
}

///|
/// Strips exactly `page` and the slash after it, since a page name may itself hold slashes.
fn wiki_attachment_of(page : String, path : Json) -> Json raise @trac.TracError {
  guard path is String(path) &&
    path.strip_prefix(path_of(page, "")) is Some(filename) else {
    raise @trac.unexpected("wiki.listAttachments")
  }
  { "filename": Json(filename.to_owned()) }
}
