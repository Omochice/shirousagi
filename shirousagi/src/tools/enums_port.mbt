///|
/// The Trac operations behind `trac_enums`.
pub(open) trait EnumPort {
  async fn enum_names(Self, kind : @enums.Kind) -> Array[String] raise @trac.TracError
  async fn get_enum(Self, kind : @enums.Kind, name : String) -> String raise @trac.TracError
  async fn ticket_statuses(Self) -> Array[String] raise @trac.TracError
  async fn create_enum(Self, kind : @enums.Kind, name : String, value~ : String) -> Unit raise @trac.TracError
  async fn update_enum(Self, kind : @enums.Kind, name : String, value~ : String) -> Unit raise @trac.TracError
  async fn delete_enum(Self, kind : @enums.Kind, name : String) -> Unit raise @trac.TracError
}

///|
pub impl EnumPort for @trac.Trac with fn enum_names(self, kind) {
  self |> @enums.names(kind)
}

///|
pub impl EnumPort for @trac.Trac with fn get_enum(self, kind, name) {
  self |> @enums.get(kind, name)
}

///|
pub impl EnumPort for @trac.Trac with fn ticket_statuses(self) {
  self |> @enums.statuses()
}

///|
pub impl EnumPort for @trac.Trac with fn create_enum(self, kind, name, value~) {
  self |> @enums.create(kind, name, value)
}

///|
pub impl EnumPort for @trac.Trac with fn update_enum(self, kind, name, value~) {
  self |> @enums.update(kind, name, value)
}

///|
pub impl EnumPort for @trac.Trac with fn delete_enum(self, kind, name) {
  self |> @enums.delete(kind, name)
}
