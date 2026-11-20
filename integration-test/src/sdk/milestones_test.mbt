///|
async test "a milestone goes through create, get, update, rename and delete" {
  let trac = @livetest.admin()
  let name = @livetest.unique("shirousagi milestone ")
  let renamed = "\{name} renamed"
  trac
  |> @milestones.create(
    name,
    @milestones.Changes::new(
      due=At("2030-01-31T00:00:00Z"),
      description="made by a test",
    ),
  )
  defer @livetest.cleanup(() => {
    (trac |> @milestones.delete(name)) catch {
      _ => ()
    }
    (trac |> @milestones.delete(renamed)) catch {
      _ => ()
    }
  })
  let got = trac |> @milestones.get(name)
  guard got
    is {
      "due": "2030-01-31T00:00:00Z",
      "completed": Null,
      "description": "made by a test",
      ..
    } else {
    fail("the created milestone lost its fields")
  }
  assert_true((trac |> @milestones.names()).contains(name))
  trac
  |> @milestones.update(
    name,
    @milestones.Changes::new(due=Unset, completed=At("2030-02-01T12:00:00Z")),
  )
  let got = trac |> @milestones.get(name)
  guard got is { "due": Null, "completed": "2030-02-01T12:00:00Z", .. } else {
    fail("the update did not clear due and set completed")
  }
  trac |> @milestones.update(name, @milestones.Changes::new(name=renamed))
  ignore(trac |> @milestones.get(renamed))
  trac |> @milestones.delete(renamed)
  assert_false((trac |> @milestones.names()).contains(renamed))
}
