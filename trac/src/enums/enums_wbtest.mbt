///|
test "each kind names its own RPC methods" {
  let kinds : Array[Kind] = [Type, Resolution, Priority, Severity]
  inspect(
    kinds.map(kind => kind.methods()).join(" "),
    content="ticket.type ticket.resolution ticket.priority ticket.severity",
  )
}
