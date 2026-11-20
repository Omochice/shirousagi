///|
/// The names of every wiki page.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn names(trac : @trac.Trac) -> Array[String] raise @trac.TracError {
  let json = trac |> @trac.call("wiki.getAllPages", [])
  guard json is Array(names) else { raise @trac.unexpected("wiki.getAllPages") }
  names.map(name => {
    guard name is String(name) else {
      raise @trac.unexpected("wiki.getAllPages")
    }
    name
  })
}

///|
/// The TracWiki text of page `name`, at `version` when given and the latest otherwise.
///
/// # Raises
/// `Fault` with code 404 when there is no such page or version, otherwise as `@trac.call` does.
pub async fn get(
  trac : @trac.Trac,
  name : String,
  version? : Int32,
) -> String raise @trac.TracError {
  let json = match version {
    Some(version) =>
      trac |> @trac.call("wiki.getPageVersion", [Json(name), Json(version)])
    None => trac |> @trac.call("wiki.getPage", [Json(name)])
  }
  guard json is String(text) else { raise @trac.unexpected("wiki.getPage") }
  text
}

///|
/// The `name`, `version`, `author`, `lastModified` and `comment` of page `name`, at `version`
/// when given and the latest otherwise.
///
/// # Raises
/// `Fault` with code 404 when there is no such page or version, otherwise as `@trac.call` does.
pub async fn info(
  trac : @trac.Trac,
  name : String,
  version? : Int32,
) -> Json raise @trac.TracError {
  match version {
    Some(version) =>
      trac |> @trac.call("wiki.getPageInfoVersion", [Json(name), Json(version)])
    None => trac |> @trac.call("wiki.getPageInfo", [Json(name)])
  }
}

///|
/// Stores `text` as the new version of page `name`, creating the page when it does not exist.
///
/// # Raises
/// `Fault` when the user may not write the page, otherwise as `@trac.call` does.
pub async fn put(
  trac : @trac.Trac,
  name : String,
  text : String,
  comment~ : String = "",
) -> Unit raise @trac.TracError {
  let json = trac
    |> @trac.call("wiki.putPage", [
      Json(name),
      Json(text),
      { "comment": Json(comment) },
    ])
  guard json is True else { raise @trac.unexpected("wiki.putPage") }
}

///|
/// Deletes page `name`, or only its `version` when given.
///
/// # Raises
/// `Fault` when there is no such page or the user lacks `WIKI_DELETE`, otherwise as `@trac.call` does.
pub async fn delete(
  trac : @trac.Trac,
  name : String,
  version? : Int32,
) -> Unit raise @trac.TracError {
  let params : Array[Json] = match version {
    Some(version) => [Json(name), Json(version)]
    None => [Json(name)]
  }
  let json = trac |> @trac.call("wiki.deletePage", params)
  guard json is True else { raise @trac.unexpected("wiki.deletePage") }
}

///|
/// The latest version of every page changed since `since`, ISO 8601 text read as UTC when it has no offset.
///
/// # Raises
/// `TracError` as `@trac.call` does.
pub async fn recent_changes(
  trac : @trac.Trac,
  since : String,
) -> Json raise @trac.TracError {
  trac |> @trac.call("wiki.getRecentChanges", [@trac.datetime(since)])
}
