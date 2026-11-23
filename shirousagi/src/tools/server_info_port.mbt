///|
/// The Trac operations behind the actions of `shirousagi_info` that contact Trac.
pub(open) trait ServerInfoPort {
  async fn trac_api_version(Self) -> Json raise @trac.TracError
  async fn wiki_rpc_version(Self) -> Int32 raise @trac.TracError
  async fn trac_methods(Self) -> Array[String] raise @trac.TracError
  async fn trac_method_help(Self, name : String) -> String raise @trac.TracError
  async fn trac_method_signature(Self, name : String) -> Array[String] raise @trac.TracError
}

///|
pub impl ServerInfoPort for @trac.Trac with fn trac_api_version(self) {
  self |> @trac.api_version()
}

///|
pub impl ServerInfoPort for @trac.Trac with fn wiki_rpc_version(self) {
  self |> @wiki.rpc_version()
}

///|
pub impl ServerInfoPort for @trac.Trac with fn trac_methods(self) {
  self |> @trac.methods()
}

///|
pub impl ServerInfoPort for @trac.Trac with fn trac_method_help(self, name) {
  self |> @trac.method_help(name)
}

///|
pub impl ServerInfoPort for @trac.Trac with fn trac_method_signature(self, name) {
  self |> @trac.method_signature(name)
}
