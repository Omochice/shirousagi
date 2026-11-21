///|
/// The Trac operations behind `trac_attachments`.
pub(open) trait AttachmentPort {
  async fn attachments(Self, target : @attachments.Target) -> Array[Json] raise @trac.TracError
  async fn get_attachment(Self, target : @attachments.Target, filename : String) -> Bytes raise @trac.TracError
  async fn put_attachment(
    Self,
    target : @attachments.Target,
    filename : String,
    content : Bytes,
    description? : String,
    replace? : Bool,
  ) -> String raise @trac.TracError
  async fn delete_attachment(
    Self,
    target : @attachments.Target,
    filename : String,
  ) -> Unit raise @trac.TracError
}

///|
pub impl AttachmentPort for @trac.Trac with fn attachments(self, target) {
  self |> @attachments.list(target)
}

///|
pub impl AttachmentPort for @trac.Trac with fn get_attachment(
  self,
  target,
  filename,
) {
  self |> @attachments.get(target, filename)
}

///|
pub impl AttachmentPort for @trac.Trac with fn put_attachment(
  self,
  target,
  filename,
  content,
  description?,
  replace?,
) {
  self |> @attachments.put(target, filename, content, description?, replace?)
}

///|
pub impl AttachmentPort for @trac.Trac with fn delete_attachment(
  self,
  target,
  filename,
) {
  self |> @attachments.delete(target, filename)
}
