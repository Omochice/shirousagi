///|
/// The Trac operations behind `trac_wiki`.
pub(open) trait WikiPort {
  async fn wiki_page_names(Self) -> Array[String] raise @trac.TracError
  async fn get_wiki_page(Self, name : String, version? : Int32) -> String raise @trac.TracError
  async fn wiki_page_info(Self, name : String, version? : Int32) -> Json raise @trac.TracError
  async fn recent_wiki_changes(Self, since : String) -> Json raise @trac.TracError
  async fn put_wiki_page(Self, name : String, text~ : String, comment? : String) -> Unit raise @trac.TracError
  async fn delete_wiki_page(Self, name : String, version? : Int32) -> Unit raise @trac.TracError
}

///|
pub impl WikiPort for @trac.Trac with fn wiki_page_names(self) {
  self |> @wiki.names()
}

///|
pub impl WikiPort for @trac.Trac with fn get_wiki_page(self, name, version?) {
  self |> @wiki.get(name, version?)
}

///|
pub impl WikiPort for @trac.Trac with fn wiki_page_info(self, name, version?) {
  self |> @wiki.info(name, version?)
}

///|
pub impl WikiPort for @trac.Trac with fn recent_wiki_changes(self, since) {
  self |> @wiki.recent_changes(since)
}

///|
pub impl WikiPort for @trac.Trac with fn put_wiki_page(
  self,
  name,
  text~,
  comment?,
) {
  self |> @wiki.put(name, text, comment?)
}

///|
pub impl WikiPort for @trac.Trac with fn delete_wiki_page(self, name, version?) {
  self |> @wiki.delete(name, version?)
}
