///|
/// The Trac operations behind `trac_search`.
pub(open) trait SearchPort {
  async fn search_filters(Self) -> Array[Json] raise @trac.TracError
  async fn search(Self, query : String, filters? : Array[String]) -> Array[Json] raise @trac.TracError
}

///|
pub impl SearchPort for @trac.Trac with fn search_filters(self) {
  self |> @search.filters()
}

///|
pub impl SearchPort for @trac.Trac with fn search(self, query, filters?) {
  self |> @search.perform(query, filters?)
}
