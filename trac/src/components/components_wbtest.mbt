///|
test "only the fields that are set are sent" {
  inspect(Changes::new().to_wire().stringify(), content="{}")
  inspect(
    Changes::new(name="ui", owner="alice", description="").to_wire().stringify(),
    content=(
      #|{"name":"ui","owner":"alice","description":""}
    ),
  )
}
