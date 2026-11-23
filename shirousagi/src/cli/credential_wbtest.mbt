///|
test "a secret holds the username and password as JSON" {
  inspect(
    encode_secret(username="alice", password="pa\"ss"),
    content=(
      #|{"username":"alice","password":"pa\"ss"}
    ),
  )
}

///|
test "every character of a password survives a round trip, NUL included" {
  for password in ["\u{0}", " edge spaces ", "\u{1F600}\n\t\\", "{\"a\":1}"] {
    let secret = encode_secret(username="alice", password~)
    assert_eq(decode_secret(secret), Some(("alice", password)))
  }
}

///|
test "a secret that is not the stored shape is unreadable" {
  for
    secret in [
      "abc123", "", "[]", "{\"username\":\"alice\"}", "{\"password\":\"pw\"}", "{\"username\":1,\"password\":\"pw\"}",
      "{\"username\":\"alice\",\"password\":\"pw\",\"extra\":true}", "{\"username\":\"\",\"password\":\"pw\"}",
      "{\"username\":\"alice\",\"password\":\"\"}",
    ] {
    assert_eq(decode_secret(secret), None, msg="\{secret} was decoded")
  }
}
