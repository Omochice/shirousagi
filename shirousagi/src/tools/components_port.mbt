///|
/// The Trac operations behind `trac_components`.
pub(open) trait ComponentPort {
  async fn component_names(Self) -> Array[String] raise @trac.TracError
  async fn get_component(Self, name : String) -> Json raise @trac.TracError
  async fn create_component(Self, name : String, changes : @components.Changes) -> Unit raise @trac.TracError
  async fn update_component(Self, name : String, changes : @components.Changes) -> Unit raise @trac.TracError
  async fn delete_component(Self, name : String) -> Unit raise @trac.TracError
}

///|
pub impl ComponentPort for @trac.Trac with fn component_names(self) {
  self |> @components.names()
}

///|
pub impl ComponentPort for @trac.Trac with fn get_component(self, name) {
  self |> @components.get(name)
}

///|
pub impl ComponentPort for @trac.Trac with fn create_component(
  self,
  name,
  changes,
) {
  self |> @components.create(name, changes)
}

///|
pub impl ComponentPort for @trac.Trac with fn update_component(
  self,
  name,
  changes,
) {
  self |> @components.update(name, changes)
}

///|
pub impl ComponentPort for @trac.Trac with fn delete_component(self, name) {
  self |> @components.delete(name)
}
