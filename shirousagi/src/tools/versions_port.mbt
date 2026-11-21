///|
/// The Trac operations behind `trac_versions`.
pub(open) trait VersionPort {
  async fn version_names(Self) -> Array[String] raise @trac.TracError
  async fn get_version(Self, name : String) -> Json raise @trac.TracError
  async fn create_version(Self, name : String, changes : @versions.Changes) -> Unit raise @trac.TracError
  async fn update_version(Self, name : String, changes : @versions.Changes) -> Unit raise @trac.TracError
  async fn delete_version(Self, name : String) -> Unit raise @trac.TracError
}

///|
pub impl VersionPort for @trac.Trac with fn version_names(self) {
  self |> @versions.names()
}

///|
pub impl VersionPort for @trac.Trac with fn get_version(self, name) {
  self |> @versions.get(name)
}

///|
pub impl VersionPort for @trac.Trac with fn create_version(self, name, changes) {
  self |> @versions.create(name, changes)
}

///|
pub impl VersionPort for @trac.Trac with fn update_version(self, name, changes) {
  self |> @versions.update(name, changes)
}

///|
pub impl VersionPort for @trac.Trac with fn delete_version(self, name) {
  self |> @versions.delete(name)
}
