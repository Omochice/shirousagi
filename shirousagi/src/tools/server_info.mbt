///|
priv enum ServerInfoAction {
  Show
  Ping
  WikiRpcVersion
  Methods
  MethodHelp(String)
  MethodSignature(String)
}

///|
/// `shirousagi_info`: the server's own version and build, a check that Trac
/// answers, and what the TracXMLRPC interface offers.
/// `show` is kept apart from the actions that contact Trac, so that an
/// unreachable Trac, when a bug report is most likely, cannot hide the
/// version.
pub fn server_info_tool(
  port : &ServerInfoPort,
  build~ : @build.BuildInfo? = @build.build,
) -> @mcp.Tool {
  let method_name = @schema.required(
    "name",
    @schema.not_blank().describe(
      "RPC method name, as `methods` lists it, such as `ticket.get`.",
    ),
  )
  @mcp.tool(
    name="shirousagi_info",
    description=describe_tool([
      "`show` reports this shirousagi server's own release version and the git commit it was built from, for bug reports and debugging; it never contacts Trac.",
      "`build` is null when the server was built from source instead of a release build, and `dirty` says whether the build had uncommitted changes.",
      "`ping` checks that Trac answers and accepts the login, and reports the TracXMLRPC API version as `[epoch, major, minor]`; a failure payload says why it did not.",
      "`wiki_rpc_version` reports the version of the WikiRPC interface Trac supports.",
      "`methods` lists every TracXMLRPC method the user may call; `method_help` answers one method's documentation and `method_signature` its signatures, each the return type followed by the parameter types, such as `array,int`.",
    ]),
    input=@schema.keyed([
      ("show", @schema.record([], _ => ServerInfoAction::Show)),
      ("ping", @schema.record([], _ => ServerInfoAction::Ping)),
      (
        "wiki_rpc_version",
        @schema.record([], _ => ServerInfoAction::WikiRpcVersion),
      ),
      ("methods", @schema.record([], _ => ServerInfoAction::Methods)),
      (
        "method_help",
        @schema.record([method_name.as_member()], v => {
          ServerInfoAction::MethodHelp(v.get(method_name))
        }),
      ),
      (
        "method_signature",
        @schema.record([method_name.as_member()], v => {
          ServerInfoAction::MethodSignature(v.get(method_name))
        }),
      ),
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
        WikiRpcVersion =>
          respond(() => { "wiki_rpc_version": Json(port.wiki_rpc_version()) })
        Methods => respond(() => port.trac_methods())
        MethodHelp(name) => respond(() => port.trac_method_help(name))
        MethodSignature(name) => respond(() => port.trac_method_signature(name))
      }
    },
  )
}
