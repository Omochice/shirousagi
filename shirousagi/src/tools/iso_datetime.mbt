///|
/// Whether `chars` holds `count` ASCII digits from `start`.
fn digits_at(chars : Array[Char], start : Int32, count : Int32) -> Bool {
  start + count <= chars.length() &&
  chars[start:start + count].iter().all(c => c is ('0'..<='9'))
}

///|
/// The number held by the two digits at `start`, which `digits_at` checked.
fn two_digits(chars : Array[Char], start : Int32) -> Int32 {
  (chars[start].to_int() - '0'.to_int()) * 10 +
  (chars[start + 1].to_int() - '0'.to_int())
}

///|
/// Whether `text` is `YYYY-MM-DDTHH:MM:SS`, with an optional fraction and an
/// optional `Z` or `±HH:MM` offset.
/// This accepts the datetimes Trac itself answers, so a value read from one
/// call can be passed back to another.
/// The text is read as chars because slicing it by UTF-16 index could split a
/// surrogate pair.
fn is_iso_datetime(text : String) -> Bool {
  let chars = text.to_array()
  guard digits_at(chars, 0, 4) &&
    chars.get(4) == Some('-') &&
    digits_at(chars, 5, 2) &&
    chars.get(7) == Some('-') &&
    digits_at(chars, 8, 2) &&
    chars.get(10) == Some('T') &&
    digits_at(chars, 11, 2) &&
    chars.get(13) == Some(':') &&
    digits_at(chars, 14, 2) &&
    chars.get(16) == Some(':') &&
    digits_at(chars, 17, 2) else {
    return false
  }
  let calendar_day = try
    @schema.iso_date().parse(Json(String::from_array(chars[:10])))
  catch {
    _ => false
  } noraise {
    _ => true
  }
  guard calendar_day &&
    two_digits(chars, 11) <= 23 &&
    two_digits(chars, 14) <= 59 &&
    two_digits(chars, 17) <= 59 else {
    return false
  }
  let mut rest = 19
  if chars.get(rest) == Some('.') {
    let start = rest + 1
    rest = start
    while digits_at(chars, rest, 1) {
      rest += 1
    }
    guard rest > start else { return false }
  }
  match chars[rest:] {
    [] | ['Z'] => true
    ['+' | '-', _, _, ':', _, _] =>
      digits_at(chars, rest + 1, 2) && digits_at(chars, rest + 4, 2)
    _ => false
  }
}

///|
/// ISO 8601 datetime text, which the SDK hands to Trac as a datetime value.
fn iso_datetime() -> @schema.Schema[String] {
  @schema.string().refine(
    is_iso_datetime,
    "must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
    keywords=[
      (
        "pattern", "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})?$",
      ),
    ],
  )
}
