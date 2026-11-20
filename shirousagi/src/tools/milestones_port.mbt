///|
/// The Trac operations behind `trac_milestones`.
pub(open) trait MilestonePort {
  async fn milestone_names(Self) -> Array[String] raise @trac.TracError
  async fn get_milestone(Self, name : String) -> Json raise @trac.TracError
  async fn create_milestone(Self, name : String, changes : @milestones.Changes) -> Unit raise @trac.TracError
  async fn update_milestone(Self, name : String, changes : @milestones.Changes) -> Unit raise @trac.TracError
  async fn delete_milestone(Self, name : String) -> Unit raise @trac.TracError
}

///|
pub impl MilestonePort for @trac.Trac with fn milestone_names(self) {
  self |> @milestones.names()
}

///|
pub impl MilestonePort for @trac.Trac with fn get_milestone(self, name) {
  self |> @milestones.get(name)
}

///|
pub impl MilestonePort for @trac.Trac with fn create_milestone(
  self,
  name,
  changes,
) {
  self |> @milestones.create(name, changes)
}

///|
pub impl MilestonePort for @trac.Trac with fn update_milestone(
  self,
  name,
  changes,
) {
  self |> @milestones.update(name, changes)
}

///|
pub impl MilestonePort for @trac.Trac with fn delete_milestone(self, name) {
  self |> @milestones.delete(name)
}
