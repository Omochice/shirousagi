///|
test "the datetimes Trac answers and the offset forms are accepted" {
  for
    text in [
      "2026-11-20T19:53:23.200107Z", "2026-11-20T19:53:23Z", "2026-11-20T19:53:23",
      "2026-11-21T00:00:00+09:00", "2026-11-21T00:00:00-05:30",
    ] {
    assert_true(is_iso_datetime(text), msg="\{text} was rejected")
  }
}

///|
test "a date alone, a malformed time and an impossible day are rejected" {
  for
    text in [
      "2026-11-21", "2026-11-21 09:00:00", "2026-11-21T9:00:00", "2026-02-30T00:00:00",
      "2026-11-21T24:00:00", "2026-11-21T00:60:00", "2026-11-21T00:00:00.", "2026-11-21T00:00:00+0900",
      "2026-11-21T00:00:00z", "2026-11-21T00:00:00Zjunk", "2026-11-21T00:00:00.\u{1F600}",
      "\u{1F600}026-11-21T00:00:00", "2026-11-21T00:00:00+\u{1F600}:00", "",
    ] {
    assert_false(is_iso_datetime(text), msg="\{text} was accepted")
  }
}

///|
test "iso_datetime reports the expected form" {
  try iso_datetime().parse(Json("yesterday")) catch {
    error =>
      assert_eq(error.messages(), [
        "must be an ISO 8601 datetime such as 2026-11-21T09:00:00Z",
      ])
  } noraise {
    _ => fail("yesterday was accepted")
  }
}
