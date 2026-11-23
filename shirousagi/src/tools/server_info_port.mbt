///|
/// The Trac operation behind the `ping` action of `shirousagi_info`.
pub(open) trait ServerInfoPort {
  async fn trac_api_version(Self) -> Json raise @trac.TracError
}

///|
pub impl ServerInfoPort for @trac.Trac with fn trac_api_version(self) {
  self |> @trac.api_version()
}
