///|
/// The search filters the project offers, as `{name, label}`, such as `ticket` and `wiki`.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn filters(trac : @trac.Trac) -> Array[Json] raise @trac.TracError {
  let json = trac |> @trac.call("search.getSearchFilters", [])
  guard json is Array(rows) else {
    raise @trac.unexpected("search.getSearchFilters")
  }
  rows.map(filter_of)
}

///|
/// The results of searching for `query`, limited to `filters` when given and across every
/// filter otherwise, each as `{href, title, date, author, excerpt}`.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn perform(
  trac : @trac.Trac,
  query : String,
  filters? : Array[String],
) -> Array[Json] raise @trac.TracError {
  let params : Array[Json] = match filters {
    Some(filters) => [Json(query), Json(filters)]
    None => [Json(query)]
  }
  let json = trac |> @trac.call("search.performSearch", params)
  guard json is Array(rows) else {
    raise @trac.unexpected("search.performSearch")
  }
  rows.map(result_of)
}

///|
fn filter_of(row : Json) -> Json raise @trac.TracError {
  guard row is Array([name, label]) else {
    raise @trac.unexpected("search.getSearchFilters")
  }
  { "name": name, "label": label }
}

///|
fn result_of(row : Json) -> Json raise @trac.TracError {
  guard row is Array([href, title, date, author, excerpt]) else {
    raise @trac.unexpected("search.performSearch")
  }
  {
    "href": href,
    "title": title,
    "date": date,
    "author": author,
    "excerpt": excerpt,
  }
}
