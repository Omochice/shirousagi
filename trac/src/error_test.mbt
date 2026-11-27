///|
test "a fault reads as Trac's code and message" {
  let error : @trac.TracError = Fault(code=403, message="no permission")
  inspect(error, content="Trac fault 403: no permission")
}

///|
test "a rejected login reads as the username or password being rejected" {
  let error : @trac.TracError = Http(status=401)
  inspect(error, content="HTTP 401: the username or password was rejected")
}

///|
test "any other HTTP failure reads as its status alone" {
  let error : @trac.TracError = Http(status=500)
  inspect(error, content="HTTP 500")
}

///|
test "a failure without a code or status reads as its message alone" {
  let decode : @trac.TracError = Decode(message="not a reply")
  inspect(decode, content="not a reply")
  let transport : @trac.TracError = Transport(message="connection refused")
  inspect(transport, content="connection refused")
  let invalid : @trac.TracError = InvalidArgument(message="bad name")
  inspect(invalid, content="bad name")
}
