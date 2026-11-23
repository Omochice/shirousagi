///|
priv enum ServerInfoAction {
  Show
  Ping
}

///|
/// `shirousagi_info`: the server's own version and build, and a check that
/// Trac answers.
/// The two are separate actions so that `show` never contacts Trac: an
/// unreachable Trac, when a bug report is most likely, cannot hide the
/// version.
pub fn server_info_tool(
  port : &ServerInfoPort,
  build~ : @build.BuildInfo? = @build.build,
) -> @mcp.Tool {
  @mcp.tool(
    name="shirousagi_info",
    description=describe_tool([
      "`show` reports this shirousagi server's own release version and the git commit it was built from, for bug reports and debugging; it never contacts Trac.",
      "`build` is null when the server was built from source instead of a release build, and `dirty` says whether the build had uncommitted changes.",
      "`ping` checks that Trac answers and accepts the login, and reports the TracXMLRPC API version as `[epoch, major, minor]`; a failure payload says why it did not.",
    ]),
    input=@schema.keyed([
      ("show", @schema.record([], _ => ServerInfoAction::Show)),
      ("ping", @schema.record([], _ => ServerInfoAction::Ping)),
    ]),
    handler=async fn(action) {
      match action {
        Show =>
          success({
            "version": Json(@build.version),
            "build": match build {
              Some(info) => Json(info)
              None => Json::null()
            },
          })
        Ping => respond(() => { "api_version": port.trac_api_version() })
      }
    },
  )
}
