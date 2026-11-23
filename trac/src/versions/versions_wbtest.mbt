///|
test "an unset time is sent as the 0 Trac reads as no date" {
  inspect(Changes::new().to_wire().stringify(), content="{}")
  inspect(
    Changes::new(name="2.0", time=Unset, description="").to_wire().stringify(),
    content=(
      #|{"name":"2.0","time":0,"description":""}
    ),
  )
  inspect(
    Changes::new(time=At("2030-01-01T00:00:00Z")).to_wire().stringify(),
    content=(
      #|{"time":{"__jsonclass__":["datetime","2030-01-01T00:00:00Z"]}}
    ),
  )
}
